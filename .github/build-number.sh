#!/usr/bin/env bash
# The version and build number, for every workflow that stamps one.
#
# `github.run_number` is scoped **per workflow**, so the rolling `dev` builds
# and the tagged releases were counting from two different places: a tagged
# build carried a number from a counter that started at 1 while `dev` was in
# the forties. The updater compares those numbers as numbers, and always
# against the `dev` tag — so an installed copy of a tagged release was either
# offered an endless "upgrade" that was older than what it was running, or,
# once the release counter overtook, told it was current forever.
#
# The commit count is one number both workflows can reach: identical for the
# same commit however it is built, monotonic along a branch, and small enough
# for an Android versionCode, which `github.run_id` is not.
#
# The marketing version comes off the pubspec so that bumping it is one edit
# rather than four workflow lines and a Dart constant, any one of which could
# be forgotten and produce a build labelled as something it is not.
set -euo pipefail
BUILD="$(git rev-list --count HEAD)"
VERSION="$(sed -n 's/^version: \([0-9.]*\).*/\1/p' app/pubspec.yaml | head -1)"
: "${VERSION:?no version: line in app/pubspec.yaml}"
echo "version $VERSION build $BUILD from $(git rev-parse --short HEAD)"
{
  echo "MI_BUILD=$BUILD"
  echo "MI_VERSION=$VERSION"
} >> "$GITHUB_ENV"
