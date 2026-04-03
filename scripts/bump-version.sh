#!/usr/bin/env bash
set -euo pipefail

COMMIT_MSG=$(git log -1 --pretty=%B)

# Detect bump type from commit message prefix
if [[ "$COMMIT_MSG" =~ ^\[major\] ]]; then
  BUMP="major"
elif [[ "$COMMIT_MSG" =~ ^\[minor\] ]]; then
  BUMP="minor"
elif [[ "$COMMIT_MSG" =~ ^\[patch\] ]]; then
  BUMP="patch"
else
  echo "No version keyword found, skipping bump."
  exit 0
fi

# Read current version
if [ -f package.json ]; then
  CURRENT=$(node -p "require('./package.json').version")
elif [ -f VERSION ]; then
  CURRENT=$(cat VERSION | tr -d '[:space:]')
else
  echo "No package.json or VERSION file found."
  exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

# Calculate new version
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "Bumping $CURRENT → $NEW_VERSION ($BUMP)"

# Write new version
if [ -f package.json ]; then
  npm version "$NEW_VERSION" --no-git-tag-version --allow-same-version
  git add package.json package-lock.json 2>/dev/null || git add package.json
elif [ -f VERSION ]; then
  echo "$NEW_VERSION" > VERSION
  git add VERSION
fi

# Amend the commit with version bump
git commit --amend --no-edit

# Export for use in workflow
echo "NEW_VERSION=$NEW_VERSION" >> "$GITHUB_ENV"
echo "BUMPED=true" >> "$GITHUB_ENV"
