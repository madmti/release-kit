# Bash release kit for Git

This is a pure Bash release kit for Git repositories, designed to automate the process of creating releases. It includes a script that can be integrated into CI/CD pipelines, such as GitHub Actions.

## Example workflow for GitHub Actions
Create the `.github/` folder in your repository if it doesn't exist yet.
```sh
mkdir -p .github/workflows
```

Add this repo as a submodule to your project in the path `.github/release-kit`:
```sh
git submodule add https://github.com/madmti/release-kit.git .github/release-kit
```

Then create a workflow file in `.github/workflows/release.yml` with the following content:

```yaml
name: Bash Release

on:
  push:
    branches:
      - main

permissions:
  contents: write # This permits creating releases

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          submodules: recursive

      - name: Exec Release Script
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} # This token is needed to create releases
        run: ./.github/release-kit/release.sh
```

This workflow will trigger on every push to the `main` branch, executing the `release.sh` script from the release kit submodule. Make sure to adjust the branch name if your main branch is named differently.
