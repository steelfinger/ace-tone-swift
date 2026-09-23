#!/bin/sh
# Xcode Cloud: RhythmAce.xcodeproj is generated from project.yml and not
# committed, so generate it before Xcode Cloud resolves the project.
# App Store Connect rejects duplicate build numbers, so the Xcode Cloud
# build number replaces CURRENT_PROJECT_VERSION (this checkout only).
set -eu

cd "${CI_PRIMARY_REPOSITORY_PATH:-$(dirname "$0")/..}"

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
    sed -i '' "s/CURRENT_PROJECT_VERSION: \"1\"/CURRENT_PROJECT_VERSION: \"${CI_BUILD_NUMBER}\"/" project.yml
fi

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
command -v xcodegen >/dev/null 2>&1 || brew install xcodegen

xcodegen generate
