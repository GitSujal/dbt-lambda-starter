# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email the maintainers directly or use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability).

We will acknowledge your report within 48 hours and provide a detailed response within 5 business days.

## Security Considerations

This project deploys AWS infrastructure. Please review the following before deploying:

### Credentials and Secrets

- **Never commit** `.env`, `terraform.tfvars`, `*.tfstate`, or credential files
- Use `.env.example` and `terraform.tfvars.example` as templates
- Store sensitive values in AWS Secrets Manager or environment variables
- GitHub Actions authentication uses OIDC federation (no long-lived credentials)

### AWS Infrastructure

- All S3 buckets block public access and enforce HTTPS-only
- dbt docs are served via CloudFront with Origin Access Control (bucket stays private)
- Lambda IAM roles follow least-privilege principles
- S3 buckets use AES256 server-side encryption
- Versioning is enabled on all data buckets

### CI/CD Pipeline

- GitHub OIDC trust is scoped to `repo:OWNER/REPO:environment:ENV` (not branch-based)
- IAM roles are per-repository and per-environment
- No long-lived AWS credentials are stored in GitHub

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 1.x     | :white_check_mark: |

## Dependencies

This project depends on:

- **Terraform AWS Provider** (~> 5.0) -- review [HashiCorp security](https://www.hashicorp.com/security)
- **dbt-core** and **dbt-athena** -- review [dbt security](https://docs.getdbt.com/docs/security)
- **GitHub Actions** -- review [GitHub security](https://docs.github.com/en/actions/security-guides)

We recommend regularly updating dependencies and reviewing the [CHANGELOG](CHANGELOG.md) for security-related updates.
