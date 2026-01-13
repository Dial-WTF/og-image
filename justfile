# Use mise to ensure tools are in PATH
set shell := ["bash", "-c"]

# List all commands
default:
    @just --list

# Install mise and project tools
install-tools:
    @echo "Installing mise..."
    @command -v mise >/dev/null 2>&1 || curl https://mise.run | sh
    @echo "Installing project tools (elixir, erlang, node)..."
    mise install

# Setup project (run once after clone)
setup: install-tools
    mise exec -- mix deps.get
    cd priv/js && mise exec -- pnpm install
    mise exec -- mix assets.setup
    mise exec -- mix assets.build

# Start the dev server (with asset watchers)
dev:
    mise exec -- iex -S mix phx.server

# Start dev server without iex console
dev-no-iex:
    mise exec -- mix phx.server

# Install all dependencies
bootstrap:
    mise exec -- mix deps.get
    cd priv/js && mise exec -- pnpm install

# Run tests
test:
    mise exec -- mix test

# Run tests in watch mode
test-watch:
    mise exec -- mix test.watch

# Format code
fmt:
    mise exec -- mix format

# Check formatting
fmt-check:
    mise exec -- mix format --check-formatted

# Compile the project
compile:
    mise exec -- mix compile --warnings-as-errors

# Clean build artifacts
clean:
    mise exec -- mix clean
    rm -rf _build

# Build assets
assets:
    mise exec -- mix assets.build

# Deploy-ready asset build (minified)
assets-deploy:
    mise exec -- mix assets.deploy

# Run all CI checks
ci: fmt-check compile test
