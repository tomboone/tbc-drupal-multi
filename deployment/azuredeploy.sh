#!/bin/bash

# This script runs post-deployment tasks for a Drupal multisite installation
# on Azure App Service. It sets up symlinks to a persistent file share and
# then runs deployment hooks for each site.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Define each site directory and its corresponding production URL.
declare -A SITES
SITES=(
    ["default"]="jeanneandtom.com"
    ["jeannebriggs.com"]="jeannebriggs.com"
    ["rss.tomboone.com"]="rss.tomboone.com"
)

# The root directory of your application in Azure App Service.
APP_ROOT="/home/site/wwwroot"

# The path where your Azure File Share is mounted for persistent files.
# This should contain a 'sites' directory with your multisite assets.
FILES_MOUNT_PATH="/mnt/tbc-drupal-multi-config"


# --- Deployment Steps ---

echo "Navigating to the application root directory: $APP_ROOT"
cd "$APP_ROOT"

echo "Ensuring symlinks for persistent files and settings are in place..."
echo "-------------------------------------------------"

# This block should run BEFORE drush commands.
for SITE_DIR in "${!SITES[@]}"; do
    SITE_URL="${SITES[$SITE_DIR]}"
    echo ">>> Setting up symlinks for site: $SITE_URL"

    # --- Symlink for 'files' directory ---
    SOURCE_FILES_DIR="$APP_ROOT/web/sites/$SITE_DIR/files"
    TARGET_FILES_DIR="$FILES_MOUNT_PATH/sites/$SITE_DIR/files"

    # 1. Create the target directory on the file share if it doesn't exist.
    echo "Ensuring target files directory exists: $TARGET_FILES_DIR"
    mkdir -p "$TARGET_FILES_DIR"

    # 2. If the source path exists as a real directory (from git), remove it.
    if [ -d "$SOURCE_FILES_DIR" ] && [ ! -L "$SOURCE_FILES_DIR" ]; then
        echo "Warning: Found a real directory at $SOURCE_FILES_DIR. Removing it."
        rm -rf "$SOURCE_FILES_DIR"
    fi

    # 3. If the symlink doesn't exist, create it.
    if [ ! -e "$SOURCE_FILES_DIR" ]; then
        echo "Creating symlink for files: $SOURCE_FILES_DIR -> $TARGET_FILES_DIR"
        ln -s "$TARGET_FILES_DIR" "$SOURCE_FILES_DIR"
    else
        echo "Files symlink at $SOURCE_FILES_DIR already exists. Skipping."
    fi

    # --- Symlink for 'settings.local.php' ---
    SOURCE_SETTINGS_FILE="$APP_ROOT/web/sites/$SITE_DIR/settings.local.php"
    TARGET_SETTINGS_FILE="$FILES_MOUNT_PATH/sites/$SITE_DIR/settings.local.php"

    # 1. Check if the target settings file exists on the share. It should.
    if [ -f "$TARGET_SETTINGS_FILE" ]; then
        # 2. If the source path exists as a real file (from git), remove it.
        if [ -f "$SOURCE_SETTINGS_FILE" ] && [ ! -L "$SOURCE_SETTINGS_FILE" ]; then
            echo "Warning: Found a real file at $SOURCE_SETTINGS_FILE. Removing it."
            rm -f "$SOURCE_SETTINGS_FILE"
        fi

        # 3. If the symlink doesn't exist, create it.
        if [ ! -e "$SOURCE_SETTINGS_FILE" ]; then
            echo "Creating symlink for settings: $SOURCE_SETTINGS_FILE -> $TARGET_SETTINGS_FILE"
            ln -s "$TARGET_SETTINGS_FILE" "$SOURCE_SETTINGS_FILE"
        else
            echo "Settings symlink at $SOURCE_SETTINGS_FILE already exists. Skipping."
        fi
    else
        # This is a non-fatal warning. The site might not have a local settings file.
        echo "Warning: Target settings file not found at $TARGET_SETTINGS_FILE. Skipping symlink creation."
    fi

    echo ">>> Symlink setup complete for site: $SITE_URL"
done
echo "-------------------------------------------------"


echo "Starting Drush deployment hooks for all sites..."
echo "-------------------------------------------------"

for SITE_DIR in "${!SITES[@]}"; do
    SITE_URL="${SITES[$SITE_DIR]}"
    echo ""
    echo ">>> Processing site: $SITE_URL (Directory: $SITE_DIR)"

    # The -y flag automatically answers "yes" to any prompts.
    # The --uri parameter tells Drush which site to target.
    /usr/bin/php8.3 vendor/bin/drush --uri="https://$SITE_URL" deploy:hook -y

    echo ">>> Finished processing site: $SITE_URL"
    echo "-------------------------------------------------"
done

echo ""
echo "All post-deployment tasks completed successfully!"
