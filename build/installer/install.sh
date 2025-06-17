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

set_free_port() {
  FREE_PORT_SITE=$(comm -23 <({ echo 80; seq 9080 9100; }) <(nmap --min-hostgroup 100 -p 80,9080-9100 -sS -n -T4 host.docker.internal | grep 'open' | awk '{print $1}' | cut -d'/' -f1) | head -n 1)
  FREE_PORT_SITE_HTTPS=$(comm -23 <({ echo 443; seq 8080 8100; }) <(nmap --min-hostgroup 100 -p 443,8080-8100 -sS -n -T4 host.docker.internal | grep 'open' | awk '{print $1}' | cut -d'/' -f1) | head -n 1)
  sed -i "s/80:80/${FREE_PORT_SITE}:80/g" compose.yaml
  sed -i "s/443:443/${FREE_PORT_SITE_HTTPS}:443/g" compose.yaml

  URL_SITE=https://localhost

  if [ "${FREE_PORT_SITE_HTTPS}" -ne 443 ]; then
    URL_SITE=${URL_SITE}:${FREE_PORT_SITE_HTTPS}
  fi
}

echo "Creating new Stochastix project in './${PROJECT_NAME}'..."
mkdir -p "$PROJECT_PATH/frankenphp/conf.d"

# Copy the template files from the image into the new project directory
echo "Preparing project files..."
cp /templates/compose.yaml "${PROJECT_PATH}/compose.yaml"
cp /templates/compose.override.yaml "${PROJECT_PATH}/compose.override.yaml"
cp /templates/.editorconfig "${PROJECT_PATH}/.editorconfig"
cp /templates/.gitattributes "${PROJECT_PATH}/.gitattributes"
cp /templates/frankenphp/Caddyfile "${PROJECT_PATH}/frankenphp/Caddyfile"
cp /templates/frankenphp/conf.d/20-app.dev.ini "${PROJECT_PATH}/frankenphp/conf.d/20-app.dev.ini"

echo
echo "✅ Project files created."
echo "🚀 Installing Stochastix..."
echo

# Use the mounted Docker socket to run docker-compose on the host machine,
# specifying the project directory for context.
docker run --rm -it -v "${HOST_PWD}/${PROJECT_NAME}:/app" ghcr.io/phpquant/stochastix:latest php --version
cd "${PROJECT_PATH}"
set_free_port
ABS_PATH="${HOST_PWD}/${PROJECT_NAME}" docker compose up -d

echo
echo "✅ Stochastix is running!"
echo "You can now access the UI at ${URL_SITE}."
echo
