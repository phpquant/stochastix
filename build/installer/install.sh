#!/bin/sh
set -e

# This script runs inside the installer container.
# The user's current directory on their host machine is mounted at /app.

PROJECT_NAME=$1

if [ -z "$PROJECT_NAME" ]; then
  echo "Error: Please provide a project name."
  echo "Usage: install.sh <project-name>"
  exit 1
fi

# The full path inside the container where the new project will be created
PROJECT_PATH="/app/${PROJECT_NAME}"

if [ -d "$PROJECT_PATH" ]; then
    # Check if the directory is not empty. Allows creation in an existing empty directory.
    if [ -n "$(ls -A "$PROJECT_PATH")" ]; then
        echo "Error: Directory '${PROJECT_NAME}' already exists and is not empty."
        exit 1
    fi
fi

echo "Creating new Stochastix project in './${PROJECT_NAME}'..."
mkdir -p "$PROJECT_PATH/frankenphp/conf.d"

# Copy the template files from the image into the new project directory
echo "Scaffolding project files..."
cp /templates/compose.yaml "${PROJECT_PATH}/compose.yaml"
cp /templates/compose.override.yaml "${PROJECT_PATH}/compose.override.yaml"
cp /templates/.editorconfig "${PROJECT_PATH}/.editorconfig"
cp /templates/.gitattributes "${PROJECT_PATH}/.gitattributes"
cp /templates/frankenphp/Caddyfile "${PROJECT_PATH}/frankenphp/Caddyfile"
cp /templates/frankenphp/conf.d/20-app.dev.ini "${PROJECT_PATH}/frankenphp/conf.d/20-app.dev.ini"

echo "✅ Project files created."
echo "🚀 Installing Stochastix... (This may take 3 to 10 minutes depending on your internet connection)"

# Use the mounted Docker socket to run docker-compose on the host machine,
# specifying the project directory for context.
docker run --rm -it -v "${PROJECT_NAME}:/app" ghcr.io/phpquant/stochastix:latest php --version
docker compose -p "${PROJECT_NAME}" -f "${PROJECT_PATH}/compose.yaml" up -d

echo
echo "✅ Stochastix is running!"
echo "You can now access the UI at https://localhost."
echo
