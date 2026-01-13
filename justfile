# List all commands
default:
    @just --list

# Start the dev server
dev:
    iex -S mix phx.server

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

# Run all CI checks
ci: fmt-check compile test
