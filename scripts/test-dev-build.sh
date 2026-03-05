#!/usr/bin/env bash
set -euo pipefail

# Creates a test branch with random changes in one or more container directories,
# pushes it, and opens a draft PR to trigger the dev build workflow.
#
# Usage:
#   ./scripts/test-dev-build.sh [container1] [container2] ...
#
# Examples:
#   ./scripts/test-dev-build.sh                          # random container
#   ./scripts/test-dev-build.sh python-base              # specific container
#   ./scripts/test-dev-build.sh python-base ei-models-runner  # multiple

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Determine which containers to touch
AVAILABLE=($(ls -d containers/*/ | xargs -I{} basename {}))

if [[ $# -eq 0 ]]; then
  # Pick one at random
  TARGETS=("${AVAILABLE[$RANDOM % ${#AVAILABLE[@]}]}")
else
  TARGETS=("$@")
fi

# Validate all targets exist
for T in "${TARGETS[@]}"; do
  if [[ ! -d "containers/$T" ]]; then
    echo "Error: containers/$T does not exist"
    echo "Available: ${AVAILABLE[*]}"
    exit 1
  fi
done

BRANCH="test/dev-build-$(date +%Y%m%d-%H%M%S)"

echo "Creating branch: $BRANCH"
echo "Touching containers: ${TARGETS[*]}"

git checkout -b "$BRANCH"

for T in "${TARGETS[@]}"; do
  echo "# test change $(date +%s)" >> "containers/$T/.test-trigger"
  git add "containers/$T/.test-trigger"
done

git commit -m "test: trigger dev build for ${TARGETS[*]}"
git push -u origin "$BRANCH"

gh pr create \
  --repo filippopisano/app-bricks-py \
  --title "test: dev build for ${TARGETS[*]}" \
  --body "Automated test PR to trigger the dev build workflow for: \`${TARGETS[*]}\`." \
  --draft \
  --base main \
  --head "$BRANCH"

echo ""
echo "Done. Branch: $BRANCH"
echo "Watch the workflow at: https://github.com/filippopisano/app-bricks-py/actions"
