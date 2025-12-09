# List all available tasks
default:
    @just --list

# Build Docker image and load into local registry
docker-build:
    nix build .#dockerImage
    docker load < result

# Build Docker image, load it, and run locally
docker-run: docker-build
    docker run -p 8080:80 moneybadger:latest

# Build the webapp (default nix build)
build:
    nix build

# Serve the webapp locally
serve:
    nix run .#serve
