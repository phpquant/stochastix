# This Dockerfile builds the lightweight installer image.
FROM alpine:latest

# Install tools needed by the installer script (Docker client and curl)
RUN apk add --no-cache docker-cli docker-compose curl nmap

# Copy the project templates into the image
COPY templates/ /templates/

# Copy the installer script into the image and make it executable
COPY build/installer/install.sh /usr/local/bin/install.sh
RUN chmod +x /usr/local/bin/install.sh

ENTRYPOINT ["/usr/local/bin/install.sh"]
