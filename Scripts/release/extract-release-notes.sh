#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

version="${1:-}"
output_path="${2:-/dev/stdout}"
validate_version "${version}"

notes="$(awk -v heading="## [${version}]" '
  index($0, heading) == 1 { found = 1; next }
  found && /^## \[/ { exit }
  found { print }
' "${REPOSITORY_ROOT}/CHANGELOG.md")"

grep -q '[^[:space:]]' <<<"${notes}" || fail "No release notes found for ${version}"
printf '%s\n' "${notes}" >"${output_path}"
