# Bootstrap Process

The `bootstrap_account.sh` script is a one-time-per-environment setup that connects your AWS account to GitHub Actions and initializes Terraform state storage. It does **not** modify any local files -- all configuration is stored as GitHub environment variables.

## Usage

```bash
./bootstrap_account.sh [AWS_REGION] [ENVIRONMENT]
```

| Argument      | Required | Default                        | Description                  |
|---------------|----------|--------------------------------|------------------------------|
| `AWS_REGION`  | No       | Current `aws configure` region | AWS region for all resources |
| `ENVIRONMENT` | No       | `dev`                          | `dev` or `prod`              |

```bash
# Examples
./bootstrap_account.sh ap-southeast-2        # dev in ap-southeast-2
./bootstrap_account.sh us-east-1 prod        # prod in us-east-1
./bootstrap_account.sh                       # dev in your default region
```

## Prerequisites

| Tool           | Version / Notes                              | Install                                                  |
|----------------|----------------------------------------------|----------------------------------------------------------|
| **AWS CLI**    | v2 (checked via `aws --version`)             | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
| **GitHub CLI** | Any (`gh` must be installed and authenticated) | https://cli.github.com                                   |
| **Terraform**  | >= 1.0                                       | https://developer.hashicorp.com/terraform/install        |
| **Git**        | With an `origin` remote pointing to GitHub   | --                                                       |

## Access Required

### AWS

The script validates permissions by running `aws iam list-roles`. You need **AdministratorAccess** or equivalent permissions covering:

| Service     | Actions                                                                  |
|-------------|--------------------------------------------------------------------------|
| **IAM**     | `CreateOpenIDConnectProvider`, `CreateRole`, `GetRole`, `AttachRolePolicy`, `ListRoles`, `ListOpenIDConnectProviders` |
| **STS**     | `GetCallerIdentity`                                                      |
| **S3**      | `CreateBucket`, `PutBucketVersioning`, `PutBucketEncryption`, `PutPublicAccessBlock`, `PutBucketPolicy`, `PutBucketTagging`, `ListBucket` |

### GitHub

The `gh` CLI must be authenticated (`gh auth login`) with a token that has:

- **repo** scope (read repo metadata)
- **admin:org** or repo admin permissions (create environments, set environment variables)

## What It Does

The script runs through four phases sequentially. If any step fails, execution stops immediately (`set -eo pipefail`). Existing resources are detected and reused rather than recreated.

### Phase 1 -- Validation

1. Checks AWS CLI v2 is installed
2. Checks `gh` CLI is installed
3. Verifies AWS credentials are configured (`sts get-caller-identity`)
4. Verifies sufficient AWS permissions (`iam list-roles`)
5. Resolves AWS region from the argument or `aws configure get region`
6. Updates the AWS CLI default region to the resolved value

### Phase 2 -- AWS Resources

**GitHub OIDC Provider**

- Checks if `token.actions.githubusercontent.com` already exists as an OIDC provider
- If not, creates one with `sts.amazonaws.com` as the audience

**IAM Role**

- Role name: `GitHubActions-{repo-name}-{environment}-DeployRole`
- Trust policy scoped to `repo:{owner/repo}:environment:{env}` -- only GitHub Actions workflows running in the specified GitHub environment can assume this role
- Attaches the `AdministratorAccess` managed policy

**Terraform State S3 Bucket**

- Bucket name: `{sanitized-repo-name}-terraform-state-{account-id}`
  - Sanitized name = repo name with non-alphanumeric characters removed, lowercased
- Configuration applied to the bucket:

| Setting                | Value                                |
|------------------------|--------------------------------------|
| Versioning             | Enabled                              |
| Server-side encryption | AES256                               |
| Public access          | All blocked                          |
| Bucket policy          | Deny all non-HTTPS (`s3:*`) requests |
| Tags                   | `Name`, `Type`, `Purpose`            |

### Phase 3 -- GitHub Environment

Creates (or updates) a GitHub environment matching the `ENVIRONMENT` argument and sets six environment variables:

| Variable          | Value                                   | Used By            |
|-------------------|-----------------------------------------|--------------------|
| `AWS_ROLE_ARN`    | ARN of the IAM role created above       | AWS OIDC auth      |
| `AWS_REGION`      | The resolved AWS region                 | AWS credential config |
| `AWS_ACCOUNT_ID`  | 12-digit AWS account ID                 | Reference           |
| `TFSTATE_BUCKET`  | Name of the Terraform state S3 bucket   | `terraform init`   |
| `TFSTATE_KEY`     | `terraform.tfstate`                     | `terraform init`   |
| `TFSTATE_REGION`  | Region of the state bucket              | `terraform init`   |

If the `gh` API call to create the environment fails (e.g., insufficient permissions), the script prints the manual setup URL and continues.

### Phase 4 -- Terraform Init

Runs `terraform init` with partial backend configuration:

```bash
terraform init \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -migrate-state \
  -input=false -no-color
```

This pairs with the empty `backend "s3" {}` block in `terraform.tf`. If init fails, the script prints the exact command to retry manually.

## How CI/CD Uses the Bootstrap Output

GitHub Actions workflows specify `environment: dev` (or `prod`) in the job definition, which gives them access to the environment variables set above. The workflows then:

1. Authenticate to AWS using `${{ vars.AWS_ROLE_ARN }}` and `${{ vars.AWS_REGION }}` via OIDC
2. Initialize Terraform with backend config from `${{ vars.TFSTATE_BUCKET }}`, `${{ vars.TFSTATE_KEY }}`, `${{ vars.TFSTATE_REGION }}`
3. Run `terraform plan` and `terraform apply`

No secrets, ARN files, or hardcoded values are committed to the repository.

## Idempotency

The script is safe to re-run. Each step checks for existing resources:

- OIDC provider: skipped if already exists
- IAM role: skipped if already exists
- S3 bucket: skipped if already exists (settings are re-applied)
- GitHub environment variables: overwritten with current values
- Terraform init: re-initializes the backend

## Multi-Environment Setup

Run the script once per environment to create isolated IAM roles and GitHub environments:

```bash
./bootstrap_account.sh ap-southeast-2 dev
./bootstrap_account.sh ap-southeast-2 prod
```

Each environment gets its own IAM role with a trust policy scoped to that specific GitHub environment, preventing cross-environment access.
