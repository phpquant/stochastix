# Stochastix Installer

This repository builds the official Stochastix application images and installer.

## Documentation

For the latest official documentation, visit the [Stochastix Documentation](https://phpquant.github.io/stochastix-docs).

## Quick Start

To create a new Stochastix project, run the following command, replacing `your-project-name` with the desired name for your project folder:

```bash
docker run --rm -it --pull=always -e HOST_PWD="$PWD" \
  -v "$PWD":/app -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/phpquant/stochastix-installer your-project-name
```

This command will create the `your-project-name` directory, scaffold all the necessary files, and start the application. Once it's finished, your Stochastix instance will be running and accessible.
