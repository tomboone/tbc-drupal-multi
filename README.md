# TBC Drupal Multi-Site Project

This is a multi-site Drupal installation managed with Terraform and deployed to Azure App Service.

## Sites
- jeanneandtom.com
- jeannebriggs.com  
- rsstomboone.com

## Prerequisites

### For Local Development:
- PHP 8.4+
- Composer
- Node.js (for build tools)
- Azure CLI
- Terraform
- Python 3.6+ (for pre-commit hooks)

### For Docker Development (Recommended):
- Docker & Docker Compose
- Python 3.6+ (for pre-commit hooks - runs on host)
- Azure CLI (for deployments)
- Terraform

## Development Setup

### Option 1: Docker Development (Recommended)

```bash
# 1. Start your Docker containers
docker-compose up -d

# 2. Install dependencies inside container
docker-compose exec web composer install

# 3. Set up pre-commit hooks (runs on host)
make install-precommit
# Or manually:
# pip3 install pre-commit && pre-commit install

# 4. Check environment detection
make env-info
```

### Option 2: Local Development

```bash
# 1. Install dependencies locally
composer install

# 2. Set up pre-commit hooks
make install-precommit

# 3. Check environment
make env-info
```

### 3. Infrastructure Setup
See [terraform/README.md](terraform/README.md) for infrastructure setup instructions.

## Pre-commit Hooks

This project uses pre-commit hooks to ensure:
- ✅ Drupal configuration is exported for all sites
- ✅ Composer files are valid
- ✅ YAML syntax is correct
- ✅ No trailing whitespace
- ✅ Files end with newlines
- ✅ No large files are committed

### Manual config management
```bash
# Check if config needs export
make config-check

# Export config for all sites
make config-export

# Import config for all sites (deployment)
make config-import
```

## Deployment

The project uses GitHub Actions to deploy to Azure App Service:
- **Production slot**: Main branch deploys to production
- **Staging slot**: Uses staging databases automatically

## Project Structure

```
├── web/                    # Drupal webroot
├── config/                 # Configuration per site
│   ├── jeanneandtom/      
│   ├── jeannebriggs/      
│   └── rsstomboone/       
├── terraform/             # Infrastructure as Code
├── .githooks/             # Git hooks
└── .github/workflows/     # CI/CD pipelines
```