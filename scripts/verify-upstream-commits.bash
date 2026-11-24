#!/usr/bin/env bash
# Fail unless every commit in upstream/develop that is not in HEAD is GitHub-verified.
# Requires git, gh, and GH_TOKEN (for example, the workflow's github.token).

set -euo pipefail

UPSTREAM_REPOSITORY="${UPSTREAM_REPOSITORY:-nautechsystems/nautilus_trader}"
UPSTREAM_REF="${UPSTREAM_REF:-upstream/develop}"
BASE_REF="${BASE_REF:-HEAD}"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: GitHub CLI (gh) is required" >&2
  exit 2
fi
if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "error: GH_TOKEN must be set" >&2
  exit 2
fi
if ! git rev-parse --verify "${UPSTREAM_REF}^{commit}" >/dev/null 2>&1; then
  echo "error: upstream ref '${UPSTREAM_REF}' does not resolve to a commit" >&2
  exit 2
fi
if ! git rev-parse --verify "${BASE_REF}^{commit}" >/dev/null 2>&1; then
  echo "error: base ref '${BASE_REF}' does not resolve to a commit" >&2
  exit 2
fi

commit_range=$(git rev-list "${BASE_REF}..${UPSTREAM_REF}")
if [[ -z "${commit_range}" ]]; then
  echo "No incoming upstream commits to verify."
  exit 0
fi

count=0
while IFS= read -r sha; do
  [[ -n "${sha}" ]] || continue
  verified=$(gh api "repos/${UPSTREAM_REPOSITORY}/commits/${sha}" --jq '.commit.verification.verified')
  if [[ "${verified}" != "true" ]]; then
    echo "::error::Upstream commit ${sha} is not GitHub-verified" >&2
    exit 1
  fi
  count=$((count + 1))
done <<< "${commit_range}"

echo "Verified all ${count} incoming upstream commits."
