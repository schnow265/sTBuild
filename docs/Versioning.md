# sTBuild Versioning

sTBuild uses GitVersion for semantic versioning based on Git history, tags, and branch names.

## How Versioning Works

The module's version is determined automatically using GitVersion, which follows semantic versioning (SemVer) principles.

### Version Format

```
MAJOR.MINOR.PATCH[-PRERELEASE]
```

- **MAJOR**: Incremented for incompatible API changes
- **MINOR**: Incremented for backward-compatible new features
- **PATCH**: Incremented for backward-compatible bug fixes
- **PRERELEASE**: Optional label for pre-release versions (beta, alpha, rc, etc.)

## Controlling Version Increments

You can control version increments by adding specific messages to your commit:

- `+semver:major` or `+semver:breaking`: Increments the major version
- `+semver:minor` or `+semver:feature`: Increments the minor version
- `+semver:patch` or `+semver:fix`: Increments the patch version
- `+semver:none` or `+semver:skip`: Don't increment the version

### Example Commit Messages

```
feat: Add new build template feature +semver:minor
fix: Correct path handling in symlink creation +semver:patch
BREAKING CHANGE: Restructure module API +semver:major
chore: Update documentation +semver:none
```

## Branch-Based Versioning

Different branches produce different version formats:

- **main/master**: Release versions (e.g., 1.2.3)
- **develop**: Beta pre-releases (e.g., 1.2.3-beta.1)
- **feature/***: Alpha pre-releases (e.g., 1.2.3-alpha.feature-name.1)
- **hotfix/***: Release candidates (e.g., 1.2.3-rc.1)

## Manual Version Overrides

While GitVersion is used by default, you can manually specify a version when publishing:

- In GitHub Actions: Use the "Version to publish" input on the manual trigger
- Locally: Use the `-Version` parameter with `Publish-STBuild`

## Working with GitVersion

### Get the Current Version

```powershell
# Get full version info
Get-GitVersion

# Get just the SemVer
Get-GitVersion -Format SemVer

# Get basic version (MAJOR.MINOR.PATCH)
Get-GitVersion -Format Simple
```

### Update the Module Version

```powershell
# Update the module manifest with the current GitVersion
Update-ModuleVersion -ManifestPath .\sTBuild.psd1
```

## Configuration

GitVersion's behavior is configured in the `GitVersion.yml` file at the root of the repository.
