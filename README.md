# Bash Release Kit

A zero-dependency, pure Bash release automation tool for Git repositories. It analyzes commit history based on commit messages, creates Git tags, generates Changelogs, publishes GitHub releases, and updates version numbers in specified files (npm, python, text, etc).

Designed to be **lightweight and fast**, running natively on GitHub Actions without the need for Node.js, Python, or Docker containers.

## Quick Start (GitHub Action)

The easiest way to use this tool is as a GitHub Action step.

### Create the Workflow

Create a file at `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    branches:
      - main

permissions:
  contents: write # Required to create tags and releases

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Important: Required to calculate version history

      - name: Semantic Release
        uses: madmti/bash-release-kit@main
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          # Optional (Default: release-config.json)
          # config_file: 'release-config.json'
```

That's it\! On every push to the `main` branch, the action will analyze commit messages, create a new Git tag, and publish a GitHub release.

-----

## Loop Prevention

When using **Personal Access Tokens (PAT)** instead of `secrets.GITHUB_TOKEN`, release commits can trigger new workflow runs, creating infinite loops. The Release Kit includes automatic loop detection, but you can also prevent this at the workflow level for cleaner action logs.

### Built-in Protection

The Release Kit automatically detects and prevents release loops by checking if the last commit is a release commit made by "GitHub Actions". No configuration needed - it works out of the box.

### Workflow-Level Prevention (Recommended for PAT users)

For cleaner logs when using PAT tokens, add this condition to your workflow:

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    environment: Production
    # LOOP PREVENTION: Skip if triggered by release commits
    if: github.event.head_commit.author.name != 'GitHub Actions'
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.PAT_TOKEN }}
          fetch-depth: 0
      
      - name: Semantic Release
        uses: madmti/bash-release-kit@main
        with:
          github_token: ${{ secrets.PAT_TOKEN }}
```

**Recommendation**: Use `secrets.GITHUB_TOKEN` when possible as it doesn't trigger workflow runs for its own commits, eliminating the need for loop prevention.

-----

## Configuration

The release kit uses a configuration file to define version update behavior and other settings. By default, it looks for `release-config.json` in the repository root.

### Enable IntelliSense (Recommended)

Add the `$schema` property to your JSON file to get autocompletion and validation in VS Code.

```json
{
  "$schema": "https://raw.githubusercontent.com/madmti/bash-release-kit/main/release-schema.json",
  "github": {
    "enable": true
  }
}
```

### 1\. Changelog Configuration

Control if and where the local Changelog file is generated.

```json
"changelog": {
  "enable": true,            // Default: true
  "output": "HISTORY.md"     // Default: "CHANGELOG.md"
}
```

### 2\. File Updaters (Targets)

Automatically update version numbers in your source code.

Supported types: `npm` (or `json`), `python`, `text`, `custom-regex`.

```json
"targets": [
  {
    "path": "package.json",
    "type": "npm"
  },
  {
    "path": "src/version.txt",
    "type": "text"
  },
  {
    "path": "src/app/__init__.py",
    "type": "python"
  },
  {
    "path": "src/config.h",
    "type": "custom-regex",
    "pattern": "s/^#define VERSION .*/#define VERSION \"%VERSION%\"/"
  }
]
```

**Note on `custom-regex`:**

  * Use standard `sed` substitution syntax: `s/find/replace/`.
  * Use `%VERSION%` as a placeholder for the new version number.
  * **Security:** The tool blocks regex patterns containing `e` (execute) or `w` (write) flags to prevent code injection.

### 3\. Custom Commit Types

Customize how different commit types affect the versioning and the Changelog sections.

```json
"commitTypes": [
  {
    "type": "feat",
    "section": "New Features",
    "bump": "minor"
  },
  {
    "type": "fix",
    "section": "Bug Fixes",
    "bump": "patch"
  },
  {
    "type": "docs",
    "section": "Documentation",
    "bump": "none",
    "hidden": true
  },
  {
    "type": "perf",
    "section": "Performance",
    "bump": "patch",
    "hidden": false
  }
]
```

  * **bump**: `major`, `minor`, `patch`, or `none`.
  * **hidden**: If `true`, these commits won't appear in the Changelog.

### 4\. Floating Tags

Keep your consumers up-to-date automatically by maintaining floating tags that always point to the latest stable releases.

```json
"floatingTags": {
  "latest": true,  // Updates the 'latest' tag to point to this release
  "majors": true   // Updates 'v1', 'v2', etc. to point to this release
}
```

**Use Cases:**
- **GitHub Actions**: Users can reference `uses: owner/repo@v1` to always get the latest v1.x.x
- **Docker**: Tags like `latest` automatically point to newest stable version
- **Documentation**: Simplified references without specifying exact versions

**Security Considerations:**
- **Force Push Warning**: Enabling this performs `git push --force` on specific tags
- **Default**: Both options are `false` by default for safety
- **Recommendation**: Enable only in repositories you control completely

**Technical Note:**
The tool creates floating tags but ignores them when calculating the next version. It uses `git describe --match "v*.*.*"` to ensure the next version is always calculated based on precise Semantic Version tags (e.g., `v1.2.3`) and never on floating tags (e.g., `v1`).

-----

## Versioning Rules

This tool follows [Semantic Versioning](https://semver.org/) rules based on [Conventional Commits](https://www.conventionalcommits.org/).

| Commit Message | Release Type | Example |
| :--- | :--- | :--- |
| `fix: ...` | **Patch** (`1.0.0` -\> `1.0.1`) | `fix: prevent null pointer exception` |
| `feat: ...` | **Minor** (`1.0.0` -\> `1.1.0`) | `feat: add new login button` |
| `feat!: ...` | **Major** (`1.0.0` -\> `2.0.0`) | `feat!: drop support for Node 12` |
| `BREAKING CHANGE:` | **Major** (`1.0.0` -\> `2.0.0`) | (Footer) `BREAKING CHANGE: API removed` |

> **Note:** Priority is hierarchical. A single `MAJOR` commit overrides any number of `MINOR` or `PATCH` commits.

-----

## Inputs

| Input | Description | Required | Default |
| :--- | :--- | :--- | :--- |
| `github_token` | The `GITHUB_TOKEN` secret to create releases via GitHub CLI. | **Yes** | N/A |
| `config_file` | Path to the JSON configuration file. | No | `release-config.json` |

-----

## Contributing

Contributions are welcome to Bash Release Kit! This section will help you get started with development and ensure your contributions meet basic quality standards.

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/yourusername/bash-release-kit.git
   cd release-kit
   ```

2. **Install Minimal Dependencies**
   ```bash
   # Required for local development and testing
   sudo apt-get install jq git shellcheck  # Ubuntu/Debian
   # or
   brew install jq git shellcheck          # macOS
   ```

### Code Quality Standards

This project follows the following code quality guidelines:

- **Shell Scripts**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **Documentation**: All functions must be documented using the established format
- **Security**: All user inputs and file operations must be validated
- **Testing**: Changes should be tested locally before submission

### Pre-commit Validation

Before submitting changes, run the local validation:

```bash
# Check shell script quality
shellcheck -x release.sh
find lib -name "*.sh" -exec shellcheck {} \;

# Test basic functionality
bash -n release.sh                    # Syntax check
bash -c "source lib/config.sh && source lib/log.sh && setup_config"
```

### Contribution Guidelines

1. **Branch Naming**
   - `feat/description` - New features
   - `fix/description` - Bug fixes  
   - `docs/description` - Documentation updates
   - `refactor/description` - Code improvements
   
   **Target branches:**
   - `main` - Stable production releases
   - `dev` - Development integration branch

2. **Commit Messages**
   Follow [Conventional Commits](https://www.conventionalcommits.org/):
   ```
   feat: add support for custom commit types
   fix: prevent directory traversal in file paths
   docs: update configuration examples
   ```

3. **Pull Request Process**
   - Create feature branch from `dev` for new features
   - Create hotfix branch from `main` for critical fixes
   - Ensure all GitHub Actions pass (ShellCheck runs on both `main` and `dev`)
   - Include clear description of changes
   - Add tests for new functionality when applicable

### Development Workflow

1. **Create Branch**
   ```bash
   # For new features
   git checkout dev
   git pull origin dev
   git checkout -b feat/your-feature-name
   
   # For hotfixes
   git checkout main
   git pull origin main
   git checkout -b fix/critical-issue
   ```

2. **Make Changes**
   - Follow existing code patterns
   - Maintain function documentation format
   - Add security validations for new features

3. **Test Locally**
   ```bash
   # Test with your changes
   CONFIG_FILE_PATH=".github/release-config.json" ./release.sh
   ```

4. **Submit PR**
   - Push to your fork
   - Create pull request targeting `dev` (or `main` for hotfixes)
   - Ensure ShellCheck passes on both branches
   - Include clear description of changes
   - Respond to review feedback

### Security Considerations

When contributing, pay special attention to:

- **Input validation**: All user inputs must be validated
- **Path traversal**: File paths must be checked with `_is_safe_path`
- **Command injection**: Avoid dynamic command construction
- **Regex safety**: Custom regex patterns must be validated

### Getting Help

- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Use GitHub Discussions for questions
- **Security**: Report security issues privately to the maintainers

### License

By contributing, you agree that your contributions will be licensed under the same license as the project.
