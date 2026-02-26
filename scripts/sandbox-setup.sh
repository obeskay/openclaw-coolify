#!/bin/bash
set -e

# Inherit DOCKER_HOST if set, or default to socket proxy
export DOCKER_HOST="${DOCKER_HOST:-tcp://docker-proxy:2375}"

echo "🦞 Building OpenClaw Sandbox Base Image..."

# Check if docker CLI is available
if ! command -v docker &> /dev/null; then
    echo "⚠️ Docker CLI not found in container - skipping sandbox setup"
    echo "   (Sandbox features will be disabled)"
    exit 0
fi

# Use python slim as a solid base
BASE_IMAGE="python:3.11-slim-bookworm"
TARGET_IMAGE="openclaw-sandbox:bookworm-slim"

# Check if image already exists
if docker image inspect "$TARGET_IMAGE" >/dev/null 2>&1; then
    echo "✅ Sandbox base image already exists: $TARGET_IMAGE"
    exit 0
fi

echo "   Pulling $BASE_IMAGE..."
docker pull "$BASE_IMAGE" || {
    echo "⚠️ Failed to pull sandbox base image - continuing without sandbox"
    exit 0
}

echo "   Tagging as $TARGET_IMAGE..."
docker tag "$BASE_IMAGE" "$TARGET_IMAGE"

echo "✅ Sandbox base image ready: $TARGET_IMAGE"