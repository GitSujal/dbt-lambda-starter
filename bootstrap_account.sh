#!/bin/bash
set -eo pipefail

# This script initializes the AWS account for dbt-on-Lambda deployment.
# It creates GitHub OIDC integration and Terraform state backend resources.

# Ensure AWS CLI v2 is installed
if ! aws --version | grep -q 'aws-cli/2'; then
  echo "AWS CLI v2 is required. Please install or upgrade to AWS CLI v2."
  exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "AWS credentials are not configured. Please configure your AWS CLI."
  exit 1
fi

# Check if the user has necessary permissions [ We need admin permissions for this operation ]
if ! aws sts get-caller-identity | grep -q 'AdministratorAccess'; then
  echo "AdministratorAccess policy is required. Please attach the AdministratorAccess policy to your user or login with a user that has it."
  exit 1
fi
echo "AWS CLI v2 is installed and AWS credentials are configured with necessary permissions."


# Check if default region is specified or passed as an argument
AWS_REGION="$1"
if [ -z "$AWS_REGION" ]; then
  AWS_REGION=$(aws configure get region)
  if [ -z "$AWS_REGION" ]; then
    echo "No default region specified. Please provide a default region as an argument or configure it using 'aws configure'."
    exit 1
  fi
fi

# Set/update AWS region if provided
if [ -n "$AWS_REGION" ]; then
  echo "Setting default region to $AWS_REGION"
  aws configure set region "$AWS_REGION"
fi

echo "Default region is set to $AWS_REGION"

# Create an OIDC provider for GitHub Actions if it doesn't exist
OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" --output text)
if [ -z "$OIDC_PROVIDER_ARN" ]; then
  echo "Creating OIDC provider for GitHub Actions..."
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com 
else
  echo "OIDC provider for GitHub Actions already exists."
fi

# Get GitHub repository information from git remote
GITHUB_REPO=""
if git remote get-url origin > /dev/null 2>&1; then
  REMOTE_URL=$(git remote get-url origin)
  # Extract repository name from different URL formats
  if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+/[^/]+)(\.git)?$ ]]; then
    GITHUB_REPO="${BASH_REMATCH[1]}"
    # Remove .git suffix if present
    GITHUB_REPO="${GITHUB_REPO%.git}"
    echo "Detected GitHub repository: $GITHUB_REPO"
  else
    echo "Warning: Could not parse GitHub repository from remote URL: $REMOTE_URL"
    echo "Please ensure this is a GitHub repository or manually set the repository in the IAM role trust policy."
    exit 1
  fi
else
  echo "Error: No git remote 'origin' found. Please ensure this is a git repository with a GitHub remote."
  exit 1
fi

# Create an IAM role for GitHub Actions that can assume the role CDKDeployRole using OIDC
ROLE_NAME="GitHubActionsCDKDeployRole"
if ! aws iam get-role --role-name "$ROLE_NAME" > /dev/null 2>&1; then
  echo "Creating IAM role $ROLE_NAME for GitHub Actions..."
  TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF
)
  aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document "$TRUST_POLICY"
    echo "Attaching AdministratorAccess policy to $ROLE_NAME..."
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"
else
  echo "IAM role $ROLE_NAME already exists."
fi

# save the role ARN to a .arn file for later use
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
echo "ROLE_ARN=$ROLE_ARN" > .arn
echo "Saved ROLE_ARN to .arn file."

echo ""
echo "==============================================="
echo "Initializing Terraform State Backend Resources"
echo "==============================================="
echo ""

# Create S3 bucket for Terraform state using AWS CLI
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
STATE_BUCKET="dbt-lambda-terraform-state-${ACCOUNT_ID}"

# Check if bucket already exists
if aws s3 ls "s3://${STATE_BUCKET}" > /dev/null 2>&1; then
  echo "✓ Terraform state bucket already exists: $STATE_BUCKET"
else
  echo "Creating S3 bucket for Terraform state: $STATE_BUCKET"
  aws s3 mb "s3://${STATE_BUCKET}" --region "$(aws configure get region)" 2>/dev/null || true

  if [ $? -eq 0 ]; then
    echo "✓ S3 bucket created"
  fi
fi

# Enable versioning
echo "Enabling versioning on state bucket..."
aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled \
  > /dev/null 2>&1
echo "✓ Versioning enabled"

# Enable encryption
echo "Enabling server-side encryption..."
aws s3api put-bucket-encryption \
  --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }' \
  > /dev/null 2>&1
echo "✓ Encryption enabled"

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  > /dev/null 2>&1
echo "✓ Public access blocked"

# Apply bucket policy to enforce HTTPS only
echo "Applying bucket policy (HTTPS only)..."
aws s3api put-bucket-policy \
  --bucket "$STATE_BUCKET" \
  --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Sid\": \"EnforceSSLOnly\",
        \"Effect\": \"Deny\",
        \"Principal\": \"*\",
        \"Action\": \"s3:*\",
        \"Resource\": [
          \"arn:aws:s3:::${STATE_BUCKET}\",
          \"arn:aws:s3:::${STATE_BUCKET}/*\"
        ],
        \"Condition\": {
          \"Bool\": {
            \"aws:SecureTransport\": \"false\"
          }
        }
      }
    ]
  }" \
  > /dev/null 2>&1
echo "✓ Bucket policy applied"

# Add tags to bucket
echo "Adding tags..."
aws s3api put-bucket-tagging \
  --bucket "$STATE_BUCKET" \
  --tagging 'TagSet=[{Key=Name,Value=dbt-lambda-terraform-state},{Key=Type,Value=Terraform-State},{Key=Purpose,Value=Infrastructure-State-Storage}]' \
  > /dev/null 2>&1
echo "✓ Tags added"

# Save bucket name for later use
echo "$STATE_BUCKET" > .state-bucket
echo "✓ Terraform state bucket ready: $STATE_BUCKET"

echo ""
echo "==============================================="
echo "Updating terraform configuration files"
echo "==============================================="
echo ""

# Update terraform.tf with the bucket name and region
TERRAFORM_FILE="terraform.tf"
if [ -f "$TERRAFORM_FILE" ]; then
  echo "Updating $TERRAFORM_FILE"
  echo "  - Bucket: $STATE_BUCKET"
  echo "  - Region: $AWS_REGION"

  # Replace bucket name and region in terraform.tf
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed syntax
    sed -i '' "s|bucket  = \"dbt-lambda-terraform-state-[0-9]*\"|bucket  = \"$STATE_BUCKET\"|g" "$TERRAFORM_FILE"
    sed -i '' "s|region  = \"[^\"]*\"|region  = \"$AWS_REGION\"|g" "$TERRAFORM_FILE"
  else
    # Linux sed syntax
    sed -i "s|bucket  = \"dbt-lambda-terraform-state-[0-9]*\"|bucket  = \"$STATE_BUCKET\"|g" "$TERRAFORM_FILE"
    sed -i "s|region  = \"[^\"]*\"|region  = \"$AWS_REGION\"|g" "$TERRAFORM_FILE"
  fi

  echo "✓ terraform.tf updated"
else
  echo "Warning: terraform.tf not found in project root"
fi

# Update terraform.tfvars with the region
TFVARS_FILE="terraform.tfvars"
if [ -f "$TFVARS_FILE" ]; then
  echo "Updating $TFVARS_FILE with region: $AWS_REGION"

  # Replace region in terraform.tfvars
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed syntax
    sed -i '' "s|aws_region    = \"[^\"]*\"|aws_region    = \"$AWS_REGION\"|g" "$TFVARS_FILE"
  else
    # Linux sed syntax
    sed -i "s|aws_region    = \"[^\"]*\"|aws_region    = \"$AWS_REGION\"|g" "$TFVARS_FILE"
  fi

  echo "✓ terraform.tfvars updated"
else
  echo "Warning: terraform.tfvars not found in project root"
fi

echo ""
echo "==============================================="
echo "Bootstrap Complete!"
echo "==============================================="
echo ""
echo "Summary:"
echo "  ✓ AWS CLI v2 verified"
echo "  ✓ AWS Region: $AWS_REGION"
echo "  ✓ GitHub OIDC provider configured"
echo "  ✓ GitHub Actions IAM role created: $ROLE_NAME"
echo "  ✓ Terraform state bucket initialized: $STATE_BUCKET"
echo "  ✓ Configuration files updated:"
echo "    - terraform.tf: bucket & region"
echo "    - terraform.tfvars: region"
echo ""
echo "Output Files:"
echo "  - .arn: Contains ROLE_ARN for GitHub Actions"
echo "  - .state-bucket: Contains terraform state bucket name"
echo ""
echo "Configuration:"
echo "  - AWS Region: $AWS_REGION"
echo "  - Terraform Backend Bucket: $STATE_BUCKET"
echo ""
echo "Next Steps:"
echo "  1. Review .arn file and save ROLE_ARN for GitHub Actions configuration"
echo "  2. Verify region in terraform.tfvars matches your deployment region"
echo "  3. Run: terraform init -migrate-state (to enable S3 backend)"
echo "  4. Run: terraform plan to review infrastructure changes"
echo "  5. Run: terraform apply to deploy resources"
echo ""