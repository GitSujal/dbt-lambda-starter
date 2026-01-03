# Contributing to dbt-on-Lambda Starter

Thank you for your interest in contributing to the dbt-on-Lambda starter project! We welcome bug reports, feature requests, and pull requests from the community.

## Code of Conduct

This project is committed to providing a welcoming and inclusive environment. All contributors are expected to treat each other with respect and professionalism.

## Getting Started

### 1. Fork and Clone

```bash
git clone https://github.com/yourusername/dbt-lambda-starter.git
cd dbt-lambda-starter
```

### 2. Set Up Development Environment

```bash
# Install dependencies
uv sync

# Activate virtual environment
source .venv/bin/activate
```

### 3. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

## Development Workflow

### Making Changes

1. **Terraform Changes**
   - Run `terraform validate` to check syntax
   - Run `terraform fmt -recursive` to format code
   - Update CLAUDE.md documentation if needed

2. **dbt Changes**
   - Follow [dbt style guide](https://docs.getdbt.com/guides/dbt-models/style-guide)
   - Add tests for new models
   - Update documentation in YAML files

3. **Python Changes**
   - Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/) style guide
   - Use type hints
   - Format code with Black: `black .`

4. **Documentation Changes**
   - Keep README.md up-to-date
   - Update CHANGELOG.md
   - Add examples where helpful

### Testing Your Changes

```bash
# Validate Terraform
terraform validate
terraform plan

# Test dbt project
cd dbt
dbt run --select +my_model
dbt test

# Format code
terraform fmt -recursive
black .
```

## Pull Request Process

### Before Submitting

1. **Update Documentation**
   - Update README.md if behavior changes
   - Add entry to CHANGELOG.md under "Unreleased"
   - Update CLAUDE.md if infrastructure changes

2. **Validate Changes**
   - Run `terraform validate` and `terraform fmt`
   - Run dbt tests and validation
   - Ensure no sensitive data is committed

3. **Commit Messages**
   - Use clear, descriptive commit messages
   - Reference issues when applicable: "Fixes #123"
   - Use present tense: "Add feature" not "Added feature"

### Submitting

1. Push your branch: `git push origin feature/your-feature-name`
2. Create a Pull Request with:
   - Clear title describing the change
   - Description of what changed and why
   - Reference to related issues
   - Test results and examples

### PR Guidelines

- **Small PRs are better**: Keep changes focused and reviewable
- **Documentation first**: Document changes before implementation
- **No breaking changes**: Maintain backward compatibility when possible
- **Test thoroughly**: Include tests for new functionality
- **Code review**: Be open to feedback and suggestions

## Reporting Issues

### Bug Reports

Include:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Terraform version (`terraform --version`)
- dbt version (`dbt --version`)
- Error messages and logs
- Environment details (AWS region, Python version, etc.)

### Feature Requests

Include:
- Clear description of desired functionality
- Use case and motivation
- Any relevant examples
- Proposed implementation (if applicable)

## Types of Contributions

### Code Contributions
- Bug fixes
- New features
- Performance improvements
- Code refactoring

### Documentation Contributions
- Typo fixes
- Clarifications and examples
- New guides or tutorials
- Better error messages

### Community Contributions
- Stack Overflow answers
- Blog posts or articles
- Example projects
- Community support

## Development Tips

### Local Testing

```bash
# Initialize Terraform (first time)
terraform init

# Plan your infrastructure changes
terraform plan -var-file="envs/dev/terraform.tfvars"

# Apply to dev environment (be careful!)
terraform apply -var-file="envs/dev/terraform.tfvars"

# View Lambda logs
aws logs tail /aws/lambda/dev-dbt-runner --follow

# Invoke Lambda manually
aws lambda invoke \
  --function-name dev-dbt-runner \
  --payload '{"command": ["test"], "cli_args": []}' \
  response.json
```

### Debugging dbt Issues

```bash
# Run with debug output
dbt run --debug

# Validate YAML
dbt parse

# Check data lineage
dbt docs generate
```

### VSCode Tips

- Install recommended extensions: `Ctrl+Shift+X` → filter by `@recommended`
- Use dbt Power User for model visualization
- Use GitLens for commit history
- Format on save: `Shift+Alt+F`

## Code Style Guidelines

### Terraform

```hcl
# Use 2-space indentation
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"

  tags = {
    Name = "Example"
  }
}
```

### Python

```python
# Use 4-space indentation, Black format
def handler(event, context):
    """Lambda handler for dbt execution."""
    command = event.get("command", ["build"])
    cli_args = event.get("cli_args", [])

    return execute_dbt(command, cli_args)
```

### dbt

```sql
-- Use lowercase for SQL keywords
-- Use ref() for model dependencies
-- Add tests and documentation

{{ config(materialized='table') }}

select
  id,
  name,
  created_at
from {{ ref('staging_users') }}
where deleted_at is null
```

## Licensing

By contributing to dbt-on-Lambda, you agree that your contributions will be licensed under the MIT License.

## Questions?

- Check existing issues and discussions
- Review CLAUDE.md for project guidelines
- Open a new issue with the "question" label

---

Thank you for contributing! Your help makes this project better for everyone.
