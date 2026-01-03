# VSCode Configuration for dbt-on-Lambda

This directory contains pre-configured VSCode settings to provide an optimal development experience for dbt, Terraform, and Python development.

## Included Configuration Files

### `settings.json`
The main VSCode workspace settings that configure:
- **Python**: Uses local `.venv` interpreter with black formatter
- **dbt**: Enables lineage panel and Jinja syntax highlighting
- **Terraform**: Configured with HashiCorp's Terraform extension
- **File Associations**: Jinja templates for dbt YAML, SQL, and docs
- **Environment Variables**: Pre-configured for dbt and Terraform
- **Code Style**: 2-space indentation, rulers at 80/120 characters

### `extensions.json`
A curated list of recommended extensions for dbt power users:
- **dbt Power User** - Complete dbt IDE integration with autocompletion
- **SQL Tools** - SQL editing, formatting, and execution
- **Python & Pylance** - Full Python language support
- **Terraform** - HashiCorp official Terraform extension
- **AWS Toolkit** - AWS service integration and debugging
- **GitLens** - Advanced Git visualization
- And more for productivity and code quality

### `mcp.json`
Model Context Protocol (MCP) server configuration enabling AI-powered features:
- **Terraform MCP** - Intelligent Terraform assistance via Docker
- **dbt MCP** - Real-time dbt model insights and validation

## Setup Instructions

### 1. Install Recommended Extensions

When you open this project in VSCode, you'll see a prompt to install the recommended extensions. Click **"Install all"** or manually install from:

```bash
# Command palette approach
Ctrl+Shift+X (open Extensions)
# Then filter by "@recommended" to see suggested extensions
```

### 2. Activate Python Virtual Environment

The settings automatically use the `.venv` directory. Activate it in your terminal:

```bash
# macOS/Linux
source .venv/bin/activate

# Windows
.venv\Scripts\activate

# Or let VSCode do it automatically in the integrated terminal
```

### 3. Enable MCP Servers (Optional, for Claude Code users)

If using Claude Code with MCP support:

1. Install Docker (for Terraform MCP)
2. Ensure `uv` is installed for dbt-mcp
3. MCP servers will activate automatically

## Key Features

### dbt Power User Extension
- **Autocompletion** for dbt models, macros, and tests
- **Lineage visualization** in the sidebar
- **dbt runner** to execute models directly from VSCode
- **YAML validation** for dbt project files
- **Ref/source navigation** with quick linking

### Python Development
- **Auto-formatting** with Black formatter on save
- **Linting** with Ruff for code quality
- **Type hints** via Pylance for intelligent suggestions
- **Debugging** support with built-in debugger

### Terraform Development
- **Syntax highlighting** and validation
- **Auto-formatting** with `terraform fmt`
- **Resource navigation** and go-to-definition
- **Plan visualization** for infrastructure changes

### Git Integration
- **GitLens** - see who changed each line, branch history
- **Git Graph** - visualize commit history
- **GitHub integration** for PR/issue management

## Environment Variables

The following environment variables are automatically set in the integrated terminal:

```
DBT_PROJECT_DIR=${workspaceFolder}/dbt
DBT_PROFILES_DIR=${workspaceFolder}/dbt
```

You can add additional variables by editing `settings.json`:

```json
"terminal.integrated.env.linux": {
  "DBT_PROJECT_DIR": "${workspaceFolder}/dbt",
  "DBT_PROFILES_DIR": "${workspaceFolder}/dbt",
  "AWS_PROFILE": "your-profile-name"  // Add this line
}
```

## Troubleshooting

### Python Interpreter Not Found
- Ensure `.venv` is created: `python -m venv .venv`
- VSCode might need restart after creating the venv
- Check: `Ctrl+Shift+P` → "Python: Select Interpreter"

### dbt Extension Not Working
- Verify dbt is installed: `.venv/bin/dbt --version`
- Check dbt profiles.yml exists: `dbt/profiles.yml`
- Review extension logs: Open Output panel → select "dbt Power User"

### Terraform Extension Issues
- Ensure HashiCorp Terraform extension is installed
- Terraform binary should be available in PATH

### MCP Servers Not Connecting
- **For Terraform MCP**: Ensure Docker is running
- **For dbt MCP**: Check `uv` is installed: `which uv` or `uv --version`
- Check Claude Code output panel for connection errors

## Customization

### Add Custom Extensions
Edit `extensions.json` and add extension IDs:

```json
{
  "recommendations": [
    "existing.extension",
    "your.new-extension"  // Add here
  ]
}
```

### Disable MCP Servers
In `mcp.json`, set `"disabled": true` for any server:

```json
{
  "servers": {
    "terraform-mcp": {
      "disabled": true  // Disable Terraform MCP
    }
  }
}
```

### Adjust Code Style
In `settings.json`, modify editor settings:

```json
{
  "editor.tabSize": 4,              // Change from 2 to 4 spaces
  "editor.insertSpaces": false,     // Use tabs instead of spaces
  "editor.rulers": [100, 120]       // Adjust ruler positions
}
```

## Resources

- [dbt Power User Docs](https://github.com/innoverio/vscode-dbt-power-user)
- [HashiCorp Terraform Extension](https://marketplace.visualstudio.com/items?itemName=hashicorp.terraform)
- [VSCode Python Extension](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
- [GitLens Documentation](https://www.gitlens.com/)
- [MCP Specification](https://modelcontextprotocol.io/)

## Tips for Power Users

1. **Use Command Palette**: `Ctrl+Shift+P` for quick access to all commands
2. **dbt Commands**: Type "dbt" in command palette to see dbt-specific operations
3. **Quick Model Testing**: Select a model file and run "dbt: Test" from palette
4. **Terraform Formatting**: `Shift+Alt+F` to format Terraform files automatically
5. **Git History**: Click the GitLens icon in the activity bar to explore project history

## Integration with Claude Code

When using Claude Code with this workspace:

1. MCP servers provide context-aware assistance
2. Terraform changes are validated before suggestions
3. dbt models are understood with full dependency resolution
4. Python code follows configured style guidelines

This setup enables seamless AI-assisted development workflow!
