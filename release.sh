#!/usr/bin/env bash
set -euo pipefail

# Clean release folder
rm -rf release
mkdir release

# --- Backend ---
echo "Building backend..."
dfx build backend --network ic

# Compress backend.wasm
echo "Compressing backend.wasm..."
cp ./.dfx/ic/canisters/backend/backend.wasm release/
gzip release/backend.wasm

# Copy backend.did
echo "Copying backend.did..."
cp ./.dfx/ic/canisters/backend/backend.did release/

# --- Frontend ---
echo "Copying frontend..."
cp -r out/frontend release/

# --- Configuration ---
echo "Copying dfx.json..."
cp release.dfx.json release/dfx.json

echo "Creating release zip file..."
cd release
zip -r identify.zip .
cd ..

echo "Release artifacts created in ./release:"
ls -l release
echo ""
echo "Release zip file created: release/identify.zip"
