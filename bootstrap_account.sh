#!/bin/bash
set -eo pipefail

# This script initializes the AWS account for dbt-on-Lambda deployment.
# It creates GitHub OIDC integration and Terraform state backend resources.
# Usage: ./bootstrap_account.sh [AWS_REGION] [ENVIRONMENT]
# ENVIRONMENT: dev (default) or prod

# Set environment (default: dev)
ENVIRONMENT="${2:-dev}"
if [[ ! "$ENVIRONMENT" =~ ^(dev|prod)$ ]]; then
  echo "Error: ENVIRONMENT must be 'dev' or 'prod', got '$ENVIRONMENT'"
  exit 1
fi

echo "Bootstrap Account Script"
echo "Environment: $ENVIRONMENT"
echo ""

# Ensure AWS CLI v2 is installed
if ! aws --version | grep -q 'aws-cli/2'; then
  echo "AWS CLI v2 is required. Please install or upgrade to AWS CLI v2."
  exit 1
fi

# Ensure gh CLI is installed
if ! command -v gh &> /dev/null; then
  echo "GitHub CLI (gh) is required. Please install it from https://cli.github.com"
  exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "AWS credentials are not configured. Please configure your AWS CLI."
  exit 1
fi

# Check if the user has necessary permissions by attempting to list IAM roles
if ! aws iam list-roles > /dev/null 2>&1; then
  echo "Error: Insufficient permissions. AdministratorAccess policy or equivalent permissions are required for bootstrapping."
  echo "Please ensure your AWS profile has permissions to create IAM roles, S3 buckets, and manage OIDC providers."
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

# Extract repo name from owner/repo format
REPO_NAME="${GITHUB_REPO#*/}"
# Sanitize repo name: remove non-alphanumeric characters and convert to lowercase
REPO_NAME_SANITIZED=$(echo "$REPO_NAME" | sed 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')
echo "Repository name: $REPO_NAME"
echo "Sanitized repository name (for S3 bucket): $REPO_NAME_SANITIZED"

# Create an IAM role for GitHub Actions with environment and repo-specific naming
ROLE_NAME="GitHubActions-${REPO_NAME}-${ENVIRONMENT}-DeployRole"
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
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:environment:${ENVIRONMENT}"
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

echo ""
echo "==============================================="
echo "Creating GitHub Environment"
echo "==============================================="
echo ""

# Get AWS account ID and role ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

echo "AWS Account ID: $ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "Role ARN: $ROLE_ARN"

# Create GitHub environment using gh CLI
if gh repo view "$GITHUB_REPO" > /dev/null 2>&1; then
  echo "Setting up GitHub environment: $ENVIRONMENT"

  # Create or update the environment using gh CLI API (PUT request)
  echo "Creating GitHub environment '$ENVIRONMENT'..."
  if gh api --method PUT \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GITHUB_REPO}/environments/${ENVIRONMENT}" > /dev/null 2>&1; then
    echo "✓ GitHub environment '$ENVIRONMENT' created successfully"
  else
    echo "⚠ Could not create environment via API. You may need to create it manually at:"
    echo "  https://github.com/${GITHUB_REPO}/settings/environments"
  fi

  # Set environment variables for this GitHub environment
  echo "Setting environment variables for '$ENVIRONMENT' environment..."

  if gh variable set AWS_ROLE_ARN --env "$ENVIRONMENT" --body "$ROLE_ARN" --repo "$GITHUB_REPO" 2>/dev/null; then
    echo "✓ AWS_ROLE_ARN variable set"
  else
    echo "⚠ Could not set AWS_ROLE_ARN via CLI."
  fi

  if gh variable set AWS_REGION --env "$ENVIRONMENT" --body "$AWS_REGION" --repo "$GITHUB_REPO" 2>/dev/null; then
    echo "✓ AWS_REGION variable set"
  else
    echo "⚠ Could not set AWS_REGION via CLI."
  fi

  if gh variable set AWS_ACCOUNT_ID --env "$ENVIRONMENT" --body "$ACCOUNT_ID" --repo "$GITHUB_REPO" 2>/dev/null; then
    echo "✓ AWS_ACCOUNT_ID variable set"
  else
    echo "⚠ Could not set AWS_ACCOUNT_ID via CLI."
  fi
else
  echo "Warning: Could not verify GitHub repository access. Please ensure gh CLI is authenticated."
  echo "You will need to manually create the '$ENVIRONMENT' environment in GitHub and set the following variables:"
  echo "  - AWS_ROLE_ARN: $ROLE_ARN"
  echo "  - AWS_REGION: $AWS_REGION"
  echo "  - AWS_ACCOUNT_ID: $ACCOUNT_ID"
fi

echo ""
echo "==============================================="
echo "Initializing Terraform State Backend Resources"
echo "==============================================="
echo ""

# Get AWS account ID first
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# Construct state bucket name using predictable pattern: {sanitized-repo-name}-terraform-state-{account_id}
# Uses sanitized repo name to ensure S3 bucket naming compliance (alphanumeric only)
STATE_BUCKET="${REPO_NAME_SANITIZED}-terraform-state-${ACCOUNT_ID}"
TFSTATE_KEY="terraform.tfstate"

echo "State bucket name (predictable pattern): $STATE_BUCKET"
echo "State key: $TFSTATE_KEY"

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

echo "✓ Terraform state bucket ready: $STATE_BUCKET"

# Set Terraform state variables in GitHub environment
echo ""
echo "Setting Terraform state variables in GitHub environment..."
if gh repo view "$GITHUB_REPO" > /dev/null 2>&1; then
  if gh variable set TFSTATE_BUCKET --env "$ENVIRONMENT" --body "$STATE_BUCKET" --repo "$GITHUB_REPO" 2>/dev/null; then
    echo "✓ TFSTATE_BUCKET variable set: $STATE_BUCKET"
  else
    echo "⚠ Could not set TFSTATE_BUCKET via CLI."
  fi

  if gh variable set TFSTATE_KEY --env "$ENVIRONMENT" --body "$TFSTATE_KEY" --repo "$GITHUB_REPO" 2>/dev/null; then
    echo "✓ TFSTATE_KEY variable set: $TFSTATE_KEY"
  else
    echo "⚠ Could not set TFSTATE_KEY via CLI."
  fi

  if gh variable set TFSTATE_REGION --env "$ENVIRONMENT" --body "$AWS_REGION" --repo "$GITHUB_REPO" 2>/dev/null; then
    echo "✓ TFSTATE_REGION variable set: $AWS_REGION"
  else
    echo "⚠ Could not set TFSTATE_REGION via CLI."
  fi
fi

echo ""
echo "==============================================="
echo "Initializing Terraform Backend"
echo "==============================================="
echo ""

# Initialize Terraform with S3 backend config and migrate state
echo "Running: terraform init with S3 backend configuration"
if terraform init \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=$TFSTATE_KEY" \
  -backend-config="region=$AWS_REGION" \
  -migrate-state \
  -input=false -no-color; then
  echo "✓ Terraform backend initialized successfully"
else
  echo "⚠ Terraform init failed. You can retry with:"
  echo "  terraform init \\"
  echo "    -backend-config=\"bucket=$STATE_BUCKET\" \\"
  echo "    -backend-config=\"key=$TFSTATE_KEY\" \\"
  echo "    -backend-config=\"region=$AWS_REGION\" \\"
  echo "    -migrate-state"
fi

echo ""
echo "==============================================="
echo "Bootstrap Complete!"
echo "==============================================="
echo ""
echo "Summary:"
echo "  ✓ AWS CLI v2 verified"
echo "  ✓ GitHub CLI verified"
echo "  ✓ AWS Region: $AWS_REGION"
echo "  ✓ Environment: $ENVIRONMENT"
echo "  ✓ Repository: $GITHUB_REPO"
echo "  ✓ GitHub OIDC provider configured"
echo "  ✓ GitHub Actions IAM role created: $ROLE_NAME"
echo "  ✓ GitHub environment setup: $ENVIRONMENT"
echo "  ✓ GitHub environment variables configured"
echo "  ✓ Terraform state bucket initialized: $STATE_BUCKET"
echo "  ✓ State bucket name uses predictable pattern: {repo}-terraform-state-{account_id}"
echo "  ✓ Terraform backend initialized with environment variables"
echo "  ✓ No file updates needed - backend config uses environment variables"
echo ""
echo "GitHub Environment Variables Set:"
echo "  AWS Credentials:"
echo "  - AWS_ROLE_ARN: $ROLE_ARN"
echo "  - AWS_REGION: $AWS_REGION"
echo "  - AWS_ACCOUNT_ID: $ACCOUNT_ID"
echo "  Terraform State:"
echo "  - TFSTATE_BUCKET: $STATE_BUCKET"
echo "  - TFSTATE_KEY: $TFSTATE_KEY"
echo "  - TFSTATE_REGION: $AWS_REGION"
echo ""
echo "Configuration:"
echo "  - AWS Region: $AWS_REGION"
echo "  - AWS Account ID: $ACCOUNT_ID"
echo "  - Environment: $ENVIRONMENT"
echo "  - Terraform Backend Bucket: $STATE_BUCKET"
echo "  - IAM Role Name: $ROLE_NAME"
echo ""
echo "IAM Role Trust Policy:"
echo "  - Repository: repo:${GITHUB_REPO}"
echo "  - Environment: ${ENVIRONMENT}"
echo "  - Only GitHub Actions workflows running in the '$ENVIRONMENT' environment can assume this role"
echo ""
echo "Next Steps:"
echo "  1. Verify Terraform backend is initialized (from output above)"
echo "  2. Review terraform.tfvars to match your deployment preferences"
echo "  3. Run: terraform plan to review infrastructure changes"
echo "  4. Run: terraform apply to deploy resources"
echo ""
echo "GitHub Actions:"
echo "  - Workflows use 'environment: ${ENVIRONMENT}'"
echo "  - Environment variables available in workflows:"
echo "    AWS: AWS_ROLE_ARN, AWS_REGION, AWS_ACCOUNT_ID"
echo "    Terraform: TFSTATE_BUCKET, TFSTATE_KEY, TFSTATE_REGION"
echo "  - Use in workflows with: \${{ vars.VAR_NAME }}"
echo "  - Terraform Init in CI (uses -reconfigure for fresh state lookup):"
echo "    terraform init \\"
echo "      -backend-config=\"bucket=\${{ vars.TFSTATE_BUCKET }}\" \\"
echo "      -backend-config=\"key=\${{ vars.TFSTATE_KEY }}\" \\"
echo "      -backend-config=\"region=\${{ vars.TFSTATE_REGION }}\" \\"
echo "      -reconfigure"
echo ""
echo "GitHub Environment:"
echo "  - Created/Updated: ${ENVIRONMENT}"
echo "  - View at: https://github.com/${GITHUB_REPO}/settings/environments/${ENVIRONMENT}"
echo ""
echo "To bootstrap another environment (e.g., prod):"
echo "  $ ./bootstrap_account.sh [AWS_REGION] prod"
echo ""
