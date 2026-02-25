# tbc-drupal-multi

Drupal 10 multisite project hosting three sites on a single codebase, deployed to Azure App Service.

## Sites

| Short name | Domain             | Drush URI          | Local URL                  | DB container (port) |
|------------|--------------------|--------------------|----------------------------|---------------------|
| jat        | jeanneandtom.com   | default            | https://jat.localhost      | tbc_drupal_jat_db (3326) |
| jbc        | jeannebriggs.com   | jeannebriggs.com   | https://jbc.localhost      | tbc_drupal_jbc_db (3327) |
| rss        | rss.tomboone.com   | rss.tomboone.com   | https://rss.tbc.localhost  | tbc_drupal_rss_db (3328) |

## Local Development

Uses Docker Compose with an external infrastructure stack (`../tbc-localdev-infra`) providing Traefik, shared MySQL, PostgreSQL, and Mailpit. This project runs its own PHP-FPM, Nginx, and per-site MySQL containers on the shared `proxy` network.

**Task runner:** All common operations use [Task](https://taskfile.dev). Run `task --list` for available commands.

**Key commands:**
- `task up` / `task down` — start/stop containers (auto-starts infra)
- `task drush:cr` — cache rebuild all sites (or `task drush:cr -- jat` for one)
- `task sync:db` — sync databases from production
- `task composer:outdated` — check for package updates

## Project Structure

- `web/` — Drupal docroot (core, contrib modules, themes installed via Composer)
- `web/sites/` — gitignored; multisite directories created locally and mounted in production
- `config/sync/{domain}/` — Drupal config per site (jeanneandtom.com, jeannebriggs.com, rss.tomboone.com)
- `drush/sites/` — Drush site aliases (prod, local)
- `drush/drush-config.yml` — local secrets for drush aliases (not tracked; see `drush/drush-config.example.yml`)
- `terraform/` — Azure infrastructure (App Service, MySQL Flexible Server, networking)
- `deployment/` — Azure startup script and Nginx config for production
- `Taskfile.yml` — local dev task runner
- `.env` — local environment variables (not tracked; see `.env.example`)

## Conventions

- Composer manages all Drupal dependencies. Never commit `vendor/`, `web/core/`, or `web/modules/contrib/`.
- Each site has its own config sync directory under `config/sync/{domain}/`.
- Drush aliases use the format `@{env}.{alias_suffix}` (e.g., `@prod.default`, `@local.jeannebriggs`).
- Traefik v3 label syntax: separate `Host()` matchers with `||` (not comma-separated).

## CI/CD

GitHub Actions workflow (`.github/workflows/azure-webapps-php.yml`) runs Terraform, builds the Composer project, and deploys to Azure App Service. Triggered on pushes to `main` that change `composer.*`, `web/**`, `config/**`, or `terraform/**`.

## Git

- Do not run git add, commit, push, or other repo-modifying commands without explicit user request.
