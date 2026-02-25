# tbc-drupal-multi

Multi-site Drupal 10 installation for Azure App Service. Three sites on one codebase:

- **jeanneandtom.com** (jat)
- **jeannebriggs.com** (jbc)
- **rss.tomboone.com** (rss)

## Prerequisites

- [Docker & Docker Compose](https://docs.docker.com/get-docker/)
- [Task](https://taskfile.dev) (task runner)
- [Composer](https://getcomposer.org/)
- [Drush](https://www.drush.org/) (installed via Composer: `vendor/bin/drush`)
- [tbc-localdev-infra](../tbc-localdev-infra) cloned as a sibling directory

## Getting Started

```bash
# Copy environment file and configure
cp .env.example .env

# Start infrastructure + project containers
task up

# Install Composer dependencies
task composer:install
```

Sites are available at:
- https://jat.localhost
- https://jbc.localhost
- https://rss.tbc.localhost

## Common Tasks

Run `task --list` for all available commands. Highlights:

```bash
# Docker
task up                  # Start all containers (auto-starts infra)
task down                # Stop all containers
task logs                # Follow container logs

# Composer
task composer:outdated   # Show outdated packages
task composer:update     # Update packages

# Drush (all sites by default, or target one: task drush:cr -- jat)
task drush:cr            # Cache rebuild
task drush:updb          # Database updates
task drush:cim           # Config import
task drush:cex           # Config export
task drush:status        # Show Drupal status

# Sync from production (requires drush alias secrets in drush/drush-config.yml)
task sync:db             # Sync databases
task sync:files          # Download site files from Azure File Share
```

## Configuration

- `drush/drush-config.yml` — Drush alias secrets (see `drush/drush-config.example.yml`)
- `.env` — Docker and Azure storage credentials (see `.env.example`)
- `config/sync/{domain}/` — Drupal config per site
