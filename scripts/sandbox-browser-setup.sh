#!/bin/bash
set -e

# Inherit DOCKER_HOST if set, or default to socket proxy
export DOCKER_HOST="${DOCKER_HOST:-tcp://docker-proxy:2375}"

echo "🦞 Building OpenClaw Sandbox Browser Image..."

# Check if docker CLI is available
if ! command -v docker &> /dev/null; then
    echo "⚠️ Docker CLI not found in container - skipping browser sandbox setup"
    echo "   (Browser sandbox features will be disabled)"
    exit 0
fi

# Use playwright image for browser capabilities
BASE_IMAGE="mcr.microsoft.com/playwright:v1.41.0-jammy"
TARGET_IMAGE="openclaw-sandbox-browser:bookworm-slim"

# Check if image already exists
if docker image inspect "$TARGET_IMAGE" >/dev/null 2>&1; then
    echo "✅ Sandbox browser image already exists: $TARGET_IMAGE"
    exit 0
fi

echo "   Pulling $BASE_IMAGE..."
docker pull "$BASE_IMAGE" || {
    echo "⚠️ Failed to pull sandbox browser image - continuing without browser sandbox"
    exit 0
}

echo "   Tagging as $TARGET_IMAGE..."
docker tag "$BASE_IMAGE" "$TARGET_IMAGE"

echo "✅ Sandbox browser image ready: $TARGET_IMAGE"