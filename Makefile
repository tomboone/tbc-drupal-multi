# Drupal Multi-site Makefile

# Site names from Terraform
SITES := jeanneandtom jeannebriggs rsstomboone

# Docker detection
DOCKER_COMPOSE := $(shell command -v docker-compose 2> /dev/null)
DOCKER := $(shell command -v docker 2> /dev/null)

# Determine Drush command based on environment
ifdef DOCKER_COMPOSE
ifneq ($(shell docker-compose ps 2>/dev/null | grep Up),)
DRUSH_CMD = docker-compose exec -T web drush
DOCKER_ENV = 🐳 Docker Compose
else
DRUSH_CMD = drush
DOCKER_ENV = 💻 Local
endif
else ifdef DOCKER
ifneq ($(shell docker ps 2>/dev/null | grep drupal),)
CONTAINER = $(shell docker ps --filter "name=drupal" --format "{{.Names}}" | head -1)
DRUSH_CMD = docker exec -i $(CONTAINER) drush
DOCKER_ENV = 🐳 Docker ($(CONTAINER))
else
DRUSH_CMD = drush
DOCKER_ENV = 💻 Local
endif
else
DRUSH_CMD = drush
DOCKER_ENV = 💻 Local
endif

.PHONY: help config-export config-import config-check install-hooks env-info

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

env-info: ## Show current environment info
	@echo "Environment: $(DOCKER_ENV)"
	@echo "Drush command: $(DRUSH_CMD)"

config-export: env-info ## Export configuration for all sites
	@echo "🔄 Exporting configuration for all sites..."
	@for site in $(SITES); do \
		if [ -d "web/sites/$$site" ]; then \
			echo "Exporting config for $$site..."; \
			$(DRUSH_CMD) --uri=$$site.local config:export -y || echo "❌ Failed to export $$site"; \
		else \
			echo "⚠️  Site $$site not found, skipping"; \
		fi; \
	done
	@echo "✅ Configuration export complete"

config-import: env-info ## Import configuration for all sites
	@echo "🔄 Importing configuration for all sites..."
	@for site in $(SITES); do \
		if [ -d "web/sites/$$site" ]; then \
			echo "Importing config for $$site..."; \
			$(DRUSH_CMD) --uri=$$site.local config:import -y || echo "❌ Failed to import $$site"; \
		else \
			echo "⚠️  Site $$site not found, skipping"; \
		fi; \
	done
	@echo "✅ Configuration import complete"

config-check: env-info ## Check if configuration is exported for all sites
	@echo "🔍 Checking configuration export status..."
	@failed=0; \
	for site in $(SITES); do \
		if [ -d "web/sites/$$site" ]; then \
			echo "Checking $$site..."; \
			if $(DRUSH_CMD) --uri=$$site.local config:status | grep -q "differences"; then \
				echo "❌ $$site has unexported config changes"; \
				failed=1; \
			else \
				echo "✅ $$site config is up to date"; \
			fi; \
		else \
			echo "⚠️  Site $$site not found, skipping"; \
		fi; \
	done; \
	if [ $$failed -eq 1 ]; then \
		echo "❌ Some sites need configuration export"; \
		echo "Run: make config-export"; \
		exit 1; \
	fi
	@echo "✅ All configurations are up to date"

install-hooks: ## Install git hooks
	@echo "📦 Installing git hooks..."
	@if [ -d ".git" ]; then \
		cp .githooks/pre-commit .git/hooks/pre-commit; \
		chmod +x .git/hooks/pre-commit; \
		echo "✅ Pre-commit hook installed"; \
	else \
		echo "❌ Not a git repository"; \
		exit 1; \
	fi

install-precommit: ## Install pre-commit framework
	@echo "📦 Installing pre-commit framework..."
	@if command -v pip3 >/dev/null 2>&1; then \
		pip3 install pre-commit; \
		pre-commit install; \
		echo "✅ Pre-commit framework installed"; \
	elif command -v pip >/dev/null 2>&1; then \
		pip install pre-commit; \
		pre-commit install; \
		echo "✅ Pre-commit framework installed"; \
	else \
		echo "❌ pip/pip3 not found. Please install Python and pip first"; \
		exit 1; \
	fi

deploy-local: env-info ## Run drush deploy for all sites locally
	@echo "🚀 Running drush deploy for all sites..."
	@for site in $(SITES); do \
		if [ -d "web/sites/$$site" ]; then \
			echo "Running drush deploy for $$site..."; \
			$(DRUSH_CMD) --uri=$$site.local deploy -v || echo "❌ Deploy failed for $$site"; \
		else \
			echo "⚠️  Site $$site not found, skipping"; \
		fi; \
	done
	@echo "✅ Drush deploy complete for all sites"

deploy-stage: ## Run drush deploy on Azure stage slot (requires WEBAPP_NAME)
	@if [ -z "$(WEBAPP_NAME)" ]; then \
		echo "❌ WEBAPP_NAME not set. Usage: make deploy-stage WEBAPP_NAME=your-app-name"; \
		exit 1; \
	fi
	@echo "🚀 Running drush deploy on Azure stage slot: $(WEBAPP_NAME)"
	@for site in $(SITES); do \
		echo "Running drush deploy for $$site on stage slot..."; \
		az webapp ssh --name $(WEBAPP_NAME) --slot stage \
			--command "cd /home/site/wwwroot && drush --uri=$$site.local deploy -v --no-interaction" \
			|| echo "❌ Deploy failed for $$site"; \
	done
	@echo "✅ Stage deployment complete"

show-db-config: ## Show database configuration for settings.php files
	@echo "📊 Database Configuration for Settings.php Files"
	@echo "=================================================="
	@cd terraform && terraform output mysql_host | xargs -I {} echo "MySQL Host: {}"
	@echo ""
	@echo "Production Databases:"
	@cd terraform && terraform output -json prod_database_names | jq -r 'to_entries[] | "  Site: \(.key) → DB: \(.key), User: \(.value)"'
	@echo ""
	@echo "Staging Databases:"  
	@cd terraform && terraform output -json stage_database_names | jq -r 'to_entries[] | "  Site: \(.key) → DB: \(.key), User: \(.value)"'
	@echo ""
	@echo "🔐 For passwords, run: cd terraform && terraform output database_passwords"

generate-settings: ## Generate settings.php templates with database config
	@echo "🏗️  Generating settings.php templates..."
	@mkdir -p config/settings-templates
	@cd terraform && \
	MYSQL_HOST=$$(terraform output -raw mysql_host) && \
	terraform output -json all_database_connections | jq -r --arg host "$$MYSQL_HOST" \
	'to_entries[] | 
	"# Settings for site: \(.key)\n" +
	"# Database: \(.value.database), User: \(.value.username)\n" +
	"$$env = $$_ENV[\"DRUPAL_ENV\"] ?? \"production\";\n\n" +
	"if ($$env === \"staging\") {\n" +
	"  $$databases[\"default\"][\"default\"] = [\n" +
	"    \"database\" => \"\(.key)_stage\",\n" +
	"    \"username\" => \"\(.value.username)s\",\n" +
	"    \"password\" => \"STAGING_PASSWORD_HERE\",\n" +
	"    \"host\" => \"\(.value.host)\",\n" +
	"    \"port\" => \"\(.value.port)\",\n" +
	"    \"driver\" => \"mysql\",\n" +
	"    \"prefix\" => \"\",\n" +
	"    \"charset\" => \"utf8mb4\",\n" +
	"    \"collation\" => \"utf8mb4_unicode_ci\",\n" +
	"  ];\n" +
	"} else {\n" +
	"  $$databases[\"default\"][\"default\"] = [\n" +
	"    \"database\" => \"\(.value.database)\",\n" +
	"    \"username\" => \"\(.value.username)\",\n" +
	"    \"password\" => \"PRODUCTION_PASSWORD_HERE\",\n" +
	"    \"host\" => \"\(.value.host)\",\n" +
	"    \"port\" => \"\(.value.port)\",\n" +
	"    \"driver\" => \"mysql\",\n" +
	"    \"prefix\" => \"\",\n" +
	"    \"charset\" => \"utf8mb4\",\n" +
	"    \"collation\" => \"utf8mb4_unicode_ci\",\n" +
	"  ];\n" +
	"}\n"' > "config/settings-templates/\(.key).settings.php.template"
	@echo "✅ Settings templates generated in config/settings-templates/"
	@echo "📝 Replace PASSWORD_HERE placeholders with actual passwords"

pre-commit-check: config-check ## Run pre-commit checks
	@echo "✅ Pre-commit checks passed"