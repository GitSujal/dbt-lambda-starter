#!/usr/bin/env bash
#
# cleanup.sh — Nuclear cleanup for dbt-on-Lambda resources
#
# Use this when terraform destroy fails due to state drift or "resource already exists" errors.
# This script deletes AWS resources directly via CLI, bypassing Terraform state.
#
# Usage:
#   ./cleanup.sh                    # Delete Terraform-managed resources only
#   ./cleanup.sh --include-stateful # Also delete TF state file and S3 data
#
# Prerequisites:
#   - AWS CLI v2 configured with appropriate permissions
#   - jq installed
#
set -euo pipefail

# ── Parse flags ──────────────────────────────────────────────────────────────
INCLUDE_STATEFUL=false
for arg in "$@"; do
  case "$arg" in
    --include-stateful) INCLUDE_STATEFUL=true ;;
    -h|--help)
      echo "Usage: $0 [--include-stateful]"
      echo ""
      echo "Deletes all dbt-on-Lambda AWS resources directly via CLI."
      echo "Use when terraform destroy fails due to state drift."
      echo ""
      echo "Options:"
      echo "  --include-stateful  Also delete TF state file from S3 and purge"
      echo "                      all data from S3 buckets (irreversible)"
      echo "  -h, --help          Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--include-stateful]"
      exit 1
      ;;
  esac
done

# ── Resolve configuration ───────────────────────────────────────────────────
# Read from terraform.tfvars if available, otherwise use defaults
TFVARS_FILE="terraform.tfvars"
if [ -f "$TFVARS_FILE" ]; then
  REGION=$(grep -E '^aws_region\s*=' "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)"/\1/' || echo "ap-southeast-2")
  PREFIX=$(grep -E '^bucket_prefix\s*=' "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)"/\1/' || echo "dbt-lambda")
  ENV=$(grep -E '^environment\s*=' "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)"/\1/' || echo "dev")
else
  REGION="${AWS_REGION:-ap-southeast-2}"
  PREFIX="${BUCKET_PREFIX:-dbt-lambda}"
  ENV="${ENVIRONMENT:-dev}"
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== dbt-on-Lambda Cleanup ==="
echo "Region:      $REGION"
echo "Prefix:      $PREFIX"
echo "Environment: $ENV"
echo "Account:     $ACCOUNT_ID"
echo "Stateful:    $INCLUDE_STATEFUL"
echo ""

# ── Confirmation ─────────────────────────────────────────────────────────────
if [ "$INCLUDE_STATEFUL" = true ]; then
  echo "WARNING: --include-stateful will delete ALL data including TF state."
  read -rp "Type 'DESTROY' to confirm: " CONFIRM
  if [ "$CONFIRM" != "DESTROY" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# ── Helper ───────────────────────────────────────────────────────────────────
delete_bucket() {
  local bucket="$1"
  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    echo "  Emptying and deleting: $bucket"
    aws s3 rb "s3://${bucket}" --force 2>/dev/null || true
  else
    echo "  Not found: $bucket (skipping)"
  fi
}

# ── CloudFront (must go first — depends on S3 origin) ───────────────────────
echo "--- CloudFront ---"
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='${PREFIX} dbt documentation'].Id" \
  --output text 2>/dev/null || true)

if [ -n "$DIST_ID" ] && [ "$DIST_ID" != "None" ]; then
  # Check if already disabled
  DIST_STATUS=$(aws cloudfront get-distribution --id "$DIST_ID" \
    --query 'Distribution.DistributionConfig.Enabled' --output text)

  if [ "$DIST_STATUS" = "True" ]; then
    echo "  Disabling distribution: $DIST_ID"
    ETAG=$(aws cloudfront get-distribution-config --id "$DIST_ID" --query 'ETag' --output text)
    CONFIG=$(aws cloudfront get-distribution-config --id "$DIST_ID" --query 'DistributionConfig')
    DISABLED_CONFIG=$(echo "$CONFIG" | python3 -c "import sys,json; c=json.load(sys.stdin); c['Enabled']=False; json.dump(c,sys.stdout)")
    echo "$DISABLED_CONFIG" > /tmp/cf-config.json
    aws cloudfront update-distribution --id "$DIST_ID" \
      --distribution-config file:///tmp/cf-config.json --if-match "$ETAG" > /dev/null
    rm -f /tmp/cf-config.json
    echo "  Waiting for distribution to deploy (this can take several minutes)..."
    aws cloudfront wait distribution-deployed --id "$DIST_ID"
  fi

  ETAG=$(aws cloudfront get-distribution --id "$DIST_ID" --query 'ETag' --output text)
  echo "  Deleting distribution: $DIST_ID"
  aws cloudfront delete-distribution --id "$DIST_ID" --if-match "$ETAG"
else
  echo "  No distribution found (skipping)"
fi

# OAC
OAC_ID=$(aws cloudfront list-origin-access-controls \
  --query "OriginAccessControlList.Items[?Name=='${PREFIX}-dbt-docs-oac'].Id" \
  --output text 2>/dev/null || true)
if [ -n "$OAC_ID" ] && [ "$OAC_ID" != "None" ]; then
  ETAG=$(aws cloudfront get-origin-access-control --id "$OAC_ID" --query 'ETag' --output text)
  echo "  Deleting OAC: ${PREFIX}-dbt-docs-oac"
  aws cloudfront delete-origin-access-control --id "$OAC_ID" --if-match "$ETAG"
else
  echo "  No OAC found (skipping)"
fi

# ── S3 Buckets ───────────────────────────────────────────────────────────────
echo ""
echo "--- S3 Buckets ---"
MANAGED_BUCKETS=(
  "${PREFIX}-raw-${ACCOUNT_ID}"
  "${PREFIX}-processed-${ACCOUNT_ID}"
  "${PREFIX}-athena-results-${ACCOUNT_ID}"
  "${PREFIX}-dbt-state-${ACCOUNT_ID}"
  "${PREFIX}-dbt-docs-${ACCOUNT_ID}"
)

STATE_BUCKET_PATTERN="terraform-state"

for BUCKET in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
  # Always skip TF state bucket unless --include-stateful
  if [[ "$BUCKET" == *"$STATE_BUCKET_PATTERN"* ]]; then
    if [ "$INCLUDE_STATEFUL" = true ]; then
      delete_bucket "$BUCKET"
    else
      echo "  KEEPING state bucket: $BUCKET (use --include-stateful to delete)"
    fi
    continue
  fi

  # Delete buckets matching known managed names or prefix pattern
  for MANAGED in "${MANAGED_BUCKETS[@]}"; do
    if [ "$BUCKET" = "$MANAGED" ]; then
      delete_bucket "$BUCKET"
      continue 2
    fi
  done

  # Also catch any other buckets created by this project (e.g. old naming conventions)
  if [[ "$BUCKET" == "${ENV}-${PREFIX}-"* ]] || [[ "$BUCKET" == "${PREFIX}-"*"-${ACCOUNT_ID}" ]]; then
    delete_bucket "$BUCKET"
  fi
done

# ── Lambda ───────────────────────────────────────────────────────────────────
echo ""
echo "--- Lambda ---"
FUNCTION_NAME="${ENV}-dbt-runner"
if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" &>/dev/null; then
  echo "  Deleting function: $FUNCTION_NAME"
  aws lambda delete-function --function-name "$FUNCTION_NAME" --region "$REGION"
else
  echo "  Function not found: $FUNCTION_NAME (skipping)"
fi

LAYER_NAME="${ENV}-dbt-layer"
LAYER_VERSIONS=$(aws lambda list-layer-versions --layer-name "$LAYER_NAME" --region "$REGION" \
  --query 'LayerVersions[].Version' --output text 2>/dev/null || true)
if [ -n "$LAYER_VERSIONS" ]; then
  for VER in $LAYER_VERSIONS; do
    echo "  Deleting layer: $LAYER_NAME:$VER"
    aws lambda delete-layer-version --layer-name "$LAYER_NAME" --version-number "$VER" --region "$REGION"
  done
else
  echo "  No layer versions for $LAYER_NAME (skipping)"
fi

# ── CloudWatch ───────────────────────────────────────────────────────────────
echo ""
echo "--- CloudWatch ---"
LOG_GROUP="/aws/lambda/${ENV}-dbt-runner"
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$REGION" \
  --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "^${LOG_GROUP}$"; then
  echo "  Deleting log group: $LOG_GROUP"
  aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$REGION"
else
  echo "  Log group not found: $LOG_GROUP (skipping)"
fi

# ── Glue ─────────────────────────────────────────────────────────────────────
echo ""
echo "--- Glue ---"
GLUE_DB="${ENV}-${PREFIX}-dataplatform"
if aws glue get-database --name "$GLUE_DB" --region "$REGION" &>/dev/null; then
  echo "  Deleting database: $GLUE_DB"
  TABLES=$(aws glue get-tables --database-name "$GLUE_DB" --region "$REGION" \
    --query 'TableList[].Name' --output text 2>/dev/null || true)
  for TABLE in $TABLES; do
    echo "    Deleting table: $TABLE"
    aws glue delete-table --database-name "$GLUE_DB" --name "$TABLE" --region "$REGION" 2>/dev/null || true
  done
  aws glue delete-database --name "$GLUE_DB" --region "$REGION"
else
  echo "  Database not found: $GLUE_DB (skipping)"
fi

# ── IAM ──────────────────────────────────────────────────────────────────────
echo ""
echo "--- IAM ---"
ROLE_NAME="${ENV}-dbt-runner-role"
POLICY_NAME="${ENV}-dbt-runner-policy"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
  echo "  Cleaning role: $ROLE_NAME"
  # Detach all managed policies
  for PA in $(aws iam list-attached-role-policies --role-name "$ROLE_NAME" \
    --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || true); do
    echo "    Detaching: $PA"
    aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$PA"
  done
  # Delete inline policies
  for IP in $(aws iam list-role-policies --role-name "$ROLE_NAME" \
    --query 'PolicyNames[]' --output text 2>/dev/null || true); do
    echo "    Deleting inline: $IP"
    aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$IP"
  done
  echo "  Deleting role: $ROLE_NAME"
  aws iam delete-role --role-name "$ROLE_NAME"
else
  echo "  Role not found: $ROLE_NAME (skipping)"
fi

if aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
  echo "  Deleting policy: $POLICY_NAME"
  for VID in $(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
    --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text 2>/dev/null || true); do
    aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$VID"
  done
  aws iam delete-policy --policy-arn "$POLICY_ARN"
else
  echo "  Policy not found: $POLICY_NAME (skipping)"
fi

# ── TF state cleanup ────────────────────────────────────────────────────────
if [ "$INCLUDE_STATEFUL" = true ]; then
  echo ""
  echo "--- Terraform State ---"
  # Clear local state
  rm -rf .terraform/terraform.tfstate .terraform.lock.hcl
  echo "  Cleared local Terraform state"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== Cleanup complete ==="
if [ "$INCLUDE_STATEFUL" = true ]; then
  echo "All resources and state deleted. Run bootstrap_account.sh to start fresh."
else
  echo "Run: terraform init -reconfigure && terraform apply"
fi
