# List all commands
default:
    @just --list

# Setup project (run once after clone)
setup:
    mix deps.get
    cd priv/js && pnpm install
    mix assets.setup
    mix assets.build

# Start the dev server (with asset watchers)
dev:
    iex -S mix phx.server

# Start dev server without iex console
dev-no-iex:
    mix phx.server

# Install all dependencies
bootstrap:
    mix deps.get
    cd priv/js && pnpm install

# Run tests
test:
    mix test

# Run tests in watch mode
test-watch:
    mix test.watch

# Format code
fmt:
    mix format

# Check formatting
fmt-check:
    mix format --check-formatted

# Compile the project
compile:
    mix compile --warnings-as-errors

# Clean build artifacts
clean:
    mix clean
    rm -rf _build

# Build assets
assets:
    mix assets.build

# Deploy-ready asset build (minified)
assets-deploy:
    mix assets.deploy

# Run all CI checks
ci: fmt-check compile test
