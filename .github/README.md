# GitHub Workflows Documentation

This directory contains GitHub Actions workflows for the Horologium Flutter project.

## Workflows

### 1. Flutter CI (`flutter_ci.yml`)
**Triggers:** Push to `main` branch, Pull Requests to `main`

**What it does:**
- ✅ Sets up Flutter environment (v3.24.3)
- ✅ Runs `flutter pub get` to install dependencies
- ✅ Runs `flutter analyze` with fatal info warnings
- ✅ Checks code formatting with `dart format`
- ✅ Runs all tests with coverage reporting
- ✅ Generates coverage reports and uploads to Codecov
- ✅ Builds debug APK and web version
- ✅ Uploads build artifacts

### 2. Flutter PR Check (`flutter_pr.yml`)
**Triggers:** Pull Requests to `main` branch only

**What it does:**
- ✅ Quick validation for PRs
- ✅ Runs analysis, formatting, and tests
- ✅ Builds debug APK to ensure buildability
- ✅ Posts results as PR comment
- ✅ Faster feedback for contributors

## Configuration Files

### Pull Request Template (`.github/PULL_REQUEST_TEMPLATE.md`)
- Standardized PR description format
- Checklist for contributors
- Testing requirements
- Type of change classification

### Dependabot (`dependabot.yml`)
- Automated dependency updates
- Weekly schedule for pub packages
- Weekly schedule for GitHub Actions
- Automatic PR creation for updates

## Setup Instructions

### 1. Enable Workflows
The workflows will automatically run when:
- Code is pushed to `main` branch
- Pull requests are opened against `main` branch

### 2. Codecov Integration (Optional)
To enable code coverage reporting:
1. Go to [codecov.io](https://codecov.io)
2. Sign up with your GitHub account
3. Add your repository
4. The workflow will automatically upload coverage reports

### 3. Branch Protection Rules (Recommended)
Set up branch protection for `main`:
1. Go to Settings → Branches
2. Add rule for `main` branch
3. Enable:
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
   - ✅ Require pull request reviews before merging
   - ✅ Include administrators

### 4. Required Status Checks
Add these status checks as required:
- `test-and-build (3.24.3)` (from flutter_ci.yml)
- `pr-check` (from flutter_pr.yml)

## Workflow Features

### 🚀 Performance Optimizations
- **Caching**: Flutter SDK and pub dependencies are cached
- **Matrix Strategy**: Easy to test multiple Flutter versions
- **Parallel Jobs**: Tests and builds run efficiently

### 🔍 Quality Checks
- **Static Analysis**: `flutter analyze` with fatal warnings
- **Code Formatting**: Enforced with `dart format`
- **Test Coverage**: Generated and tracked over time
- **Build Verification**: Ensures code compiles successfully

### 📊 Reporting
- **Coverage Reports**: Uploaded to Codecov
- **Build Artifacts**: APK and web builds available for download
- **PR Comments**: Automated status updates on pull requests

### 🔧 Maintenance
- **Dependabot**: Automated dependency updates
- **Version Pinning**: Specific Flutter version for consistency
- **Artifact Retention**: Build outputs saved for debugging

## Troubleshooting

### Common Issues

**1. Tests Failing Due to Missing Dependencies**
```yaml
- name: Get dependencies
  run: flutter pub get
```

**2. Analysis Errors**
```yaml
- name: Analyze project source
  run: flutter analyze --fatal-infos
```

**3. Formatting Issues**
```yaml
- name: Check formatting
  run: dart format --output=none --set-exit-if-changed .
```

### Debugging Workflows
1. Check the Actions tab in your GitHub repository
2. Click on the failed workflow run
3. Expand the failed step to see detailed logs
4. Common fixes:
   - Update Flutter version in workflow
   - Fix analysis warnings in code
   - Run `dart format .` locally before pushing

## Customization

### Adding New Flutter Versions
```yaml
strategy:
  matrix:
    flutter-version: ['3.24.3', '3.25.0']  # Add new versions here
```

### Adding Platform-Specific Builds
```yaml
- name: Build iOS (macOS only)
  if: runner.os == 'macOS'
  run: flutter build ios --no-codesign
```

### Custom Test Commands
```yaml
- name: Run integration tests
  run: flutter test integration_test/
```

## Best Practices

1. **Keep workflows fast** - Use caching and parallel jobs
2. **Fail fast** - Run quick checks (analysis, formatting) before expensive operations (tests, builds)
3. **Use specific versions** - Pin Flutter versions for reproducible builds
4. **Monitor coverage** - Set up coverage thresholds and tracking
5. **Regular maintenance** - Keep dependencies and actions updated