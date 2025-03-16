# GitHub Actions Automation

The sTBuild module uses GitHub Actions to automate various tasks, including testing, documentation generation, and module publishing.

## Available Workflows

### CI/CD Pipeline

The CI/CD pipeline runs automatically on pushes to main branches and pull requests:

- Runs PowerShell Script Analyzer to check code quality
- Executes Pester tests to verify functionality
- Works on both Windows and Linux environments

**Workflow file:** [.github/workflows/ci.yml](../.github/workflows/ci.yml)

### Documentation Generation

The documentation workflow automatically updates the module documentation:

- Runs when changes are made to PowerShell files in the main branch
- Generates function reference documentation
- Deploys updated documentation to GitHub Pages

**Workflow file:** [.github/workflows/docs.yml](../.github/workflows/docs.yml)

### Module Publishing

The publishing workflow publishes the module to the PowerShell Gallery:

- Triggers automatically when a new release is created
- Can be manually triggered with a specific version number
- Uses GitVersion for automatic semantic versioning
- Requires a PowerShell Gallery API key stored as a repository secret

**Workflow file:** [.github/workflows/publish.yml](../.github/workflows/publish.yml)

## Setting Up Repository Secrets

To use the publishing workflow, you need to set up a repository secret:

1. Go to your GitHub repository
2. Navigate to Settings > Secrets and variables > Actions
3. Click "New repository secret"
4. Name: `PS_GALLERY_API_KEY`
5. Value: Your PowerShell Gallery API key

## Manual Workflow Execution

You can manually trigger the documentation generation and publishing workflows:

1. Go to the "Actions" tab in your GitHub repository
2. Select the workflow you want to run
3. Click the "Run workflow" button
4. For publishing, you can optionally specify a version number (if left blank, GitVersion will be used)

## Version Management

The module uses GitVersion for semantic versioning:

- Version numbers are automatically determined based on Git history
- You can control version increments through commit messages (e.g., `+semver:minor`)
- Branch-specific version suffixes are applied to pre-release versions
- See the [Versioning documentation](./Versioning.md) for more details

## Customization

You can customize the workflows by editing the YAML files in the `.github/workflows` directory:

- Add additional test environments
- Configure notification settings
- Add deployment to additional platforms
