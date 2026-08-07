#!/usr/bin/env bash
set -euo pipefail

: "${BASE_SHA:?BASE_SHA environment variable must be set}"
ASSET_DIRS="Studio Projects|Agent Projects|Automations|LCM Resource Models|Golden Configurations"
INTEGRATION_MODELS_DIR="OpenAPIs"

echo "Diffing against merge base $BASE_SHA"

if [ "${INCLUDE_ALL_SPEC_VERSIONS:-false}" = "true" ]; then
  SPEC_PATTERN="${INTEGRATION_MODELS_DIR}/.*\.json$"
else
  SPEC_PATTERN="${INTEGRATION_MODELS_DIR}/.*-latest\.json$"
fi
ASSET_PATTERN="(${ASSET_DIRS})/.*\.json$"
ASSET_TYPE_PATTERN="${ASSET_DIRS}|${INTEGRATION_MODELS_DIR}"

# ── Combined diff ────────────────────────────────────────────────────────────
# core.quotePath=false prevents git from quoting paths that contain spaces
ALL_CHANGED=$(git -c core.quotePath=false diff --name-only --diff-filter=AM "$BASE_SHA" HEAD \
  | { grep -E "${ASSET_PATTERN}|${SPEC_PATTERN}" || true; } | jq -R . | jq -sc .)
echo "changed: $ALL_CHANGED"

# Tags each path with its specific folder type (e.g. "Automations", "OpenAPIs"),
# read directly off the path rather than a plain asset-vs-spec split.
CLASSIFIED=$(jq -c \
  --arg pattern "$ASSET_TYPE_PATTERN" \
  'map({
     path: .,
     type: (capture("/(?<type>" + $pattern + ")/") | .type)
   })' <<< "$ALL_CHANGED")

# ── Bundle grouping ────────────────────────────────────────────────────────────
# Groups changed files by their product folder (the direct parent of an
# asset-type folder), e.g. "NetBox/OpenAPIs/x.json" -> bundle "NetBox", and
# "Atlassian/Jira Cloud/OpenAPIs/x.json" -> bundle "Jira Cloud" (not
# "Atlassian/Jira Cloud" -- only the last segment before the type folder).
BUNDLES=$(jq -c \
  '
  def bundle_key:
    ((.path / ("/" + .type + "/"))[0] / "/")[-1];

  group_by(bundle_key)
  | map({
      name: (.[0] | bundle_key),
      changed: [.[] | {path, type}]
    })
  ' <<< "$CLASSIFIED")
echo "bundles: $BUNDLES"
{
  echo "bundles<<EOF"
  echo "$BUNDLES"
  echo "EOF"
} >> "$GITHUB_OUTPUT"
