## About UnitSense Calculator

UnitSense Calculator is a Flutter application that supports complex math, unit consistency, and Data Rate Projections. It allows users to enter expressions with units and calculates the result, displaying it in a user-friendly format. It supports data, numbers, time, and length units.

## GitHub Actions Setup

This project uses GitHub Actions for continuous integration and deployment. The workflow file is located in `.github/workflows/github-actions-release.yml`.

### Web Deployment

The workflow automatically builds and deploys the web app to GitHub Pages on every push to the `main` branch. To enable GitHub Pages:

1.  Go to Settings > Pages.
2.  Set the Source to Deploy from a branch.
3.  For the Branch, select `gh-pages` and `/ (root)`. (The workflow will create and push to this branch automatically).

Web app will be live at `https://rvigneshw.github.io/unit_sense_calc/`

### Release Binaries

The workflow also builds Windows, macOS, and Linux executables when a new GitHub Release is published and attaches them to that release. To create a release:

1.  Go to the Releases section of your GitHub repository.
2.  Draft a new release (e.g., using tag `v1.0.0`).
3.  Publish the release.

The desktop binaries will automatically appear attached to your release post.

### Workflow Permissions

Ensure Workflow permissions are set to allow GitHub Actions to write to the repository. Go to Settings > Actions > General and select Read and write permissions.
