# GitHub branch protection and required checks

This project uses separate GitHub Environments for deployment and keeps public browsing enabled while still requiring authenticated actions for write operations.

## Required repository settings

In GitHub → Settings → Branches, protect `main` with the following rules:

- Require a pull request before merging
- Require status checks to pass before merging
- Require the `CI / flutter` status check
- Restrict direct pushes to `main`
- Optionally require at least one review before merge

For `develop`, the same pattern is recommended for staging work if that branch is used for preview deployments.

## Required status checks

The CI workflow runs these checks automatically:

- `flutter analyze`
- `flutter test`
- `flutter build web --release`

This is defined in `.github/workflows/ci.yaml`.

## Deployment environments

The web deployment workflows are scoped to GitHub Environments:

- `production`
- `staging`

The workflow files are:

- `.github/workflows/deploy.yaml`
- `.github/workflows/deploy-staging.yaml`

Secrets should be set per environment rather than globally shared to avoid mixing production and staging credentials.

## Recommended policy

- `main`: production branch; protected by PR and CI
- `develop`: staging branch for validation and preview deployments
- `production` environment: production secrets + production deployment target
- `staging` environment: staging secrets + preview deployment target
