# Nibble's own commands. `just` lists them.

default:
    @just --list

# Start Rails, Vite and the SSR server
dev:
    bin/dev

# Rails tests: all, or the files and folders given
test *paths:
    env -u NIBBLE_THEME bin/rails test {{ paths }}

# Frontend unit tests
test-js:
    npm run test:js

# Ruby and frontend style checks
lint:
    bin/rubocop
    npm run lint
    npm run format:check

# Fix what rubocop and prettier can
fix:
    bin/rubocop -a
    npm run format

# Type-check the Control Plane, theme runtime and themes
types:
    npm run check

# Check the schema and settings against the test database
check:
    env -u NIBBLE_THEME RAILS_ENV=test bin/rails nibble:check

# Everything CI runs
ci:
    env -u NIBBLE_THEME bin/ci

# Release, publish and deploy nibble.ink: just release 0.20.0
release version:
    bin/nibble-release {{ version }} --push
    just deploy

# Deploy nibble.ink
deploy:
    bin/kamal deploy

# Pack and publish a release already tagged and pushed, e.g. after the upload failed
pack version:
    bin/nibble-release {{ version }} --pack
