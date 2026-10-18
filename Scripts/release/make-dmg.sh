#!/bin/bash

set -euo pipefail

# shellcheck source=Scripts/release/common.sh
source "$(dirname "$0")/common.sh"

version="${1:-}"
validate_version "${version}"
[[ -d "${APP_PATH}" ]] || fail "Build ${APP_NAME}.app before creating the disk image"

signing_identity="${SIGNING_IDENTITY:-${DEVELOPER_IDENTITY}}"
if [[ "${signing_identity}" == "-" ]]; then
  [[ "${ALLOW_ADHOC_SIGNING:-0}" == "1" ]] || fail "Ad hoc signing requires ALLOW_ADHOC_SIGNING=1"
fi

require_command codesign
require_command ditto
require_command python3
require_command sips
require_command swift
require_command tiffutil

mkdir -p "${DISTRIBUTION_DIRECTORY}"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "${temporary_directory}"' EXIT
volume_icon="${APP_PATH}/Contents/Resources/CharbonAppIcon.icns"
[[ -f "${volume_icon}" ]] || fail "Built app does not contain its generated icon"

# The background is drawn by a script, as a 1x and a 2x picture, and joined in one TIFF so that
# Retina screens get the 2x.
# The 2x one must stay at 144 dpi, or it counts as a huge 1x picture: `tiffutil -cat` keeps that,
# while `-cathidpicheck` resets it to 72.
background_directory="${temporary_directory}/background"
swift "${REPOSITORY_ROOT}/Scripts/make-dmg-background.swift" "${background_directory}" >/dev/null
sips -s format tiff -s dpiWidth 72 -s dpiHeight 72 \
  "${background_directory}/background.png" --out "${temporary_directory}/1x.tiff" >/dev/null
sips -s format tiff -s dpiWidth 144 -s dpiHeight 144 \
  "${background_directory}/background@2x.png" --out "${temporary_directory}/2x.tiff" >/dev/null
tiffutil -cat "${temporary_directory}/1x.tiff" "${temporary_directory}/2x.tiff" \
  -out "${temporary_directory}/background.tiff"

# dmgbuild writes the window layout itself, so it needs no Finder session and runs on a CI runner.
dmgbuild_directory="${REPOSITORY_ROOT}/.build/dmgbuild"
if [[ ! -x "${dmgbuild_directory}/bin/dmgbuild" ]]; then
  python3 -m venv "${dmgbuild_directory}"
  "${dmgbuild_directory}/bin/pip" install --quiet --disable-pip-version-check "dmgbuild==${DMGBUILD_VERSION}"
fi

dmg_path="${DISTRIBUTION_DIRECTORY}/${APP_NAME}-${version}.dmg"
rm -f "${dmg_path}"
"${dmgbuild_directory}/bin/dmgbuild" \
  -s "${REPOSITORY_ROOT}/Scripts/release/dmg-settings.py" \
  -D app="${APP_PATH}" \
  -D icon="${volume_icon}" \
  -D background="${temporary_directory}/background.tiff" \
  "${APP_NAME}" "${dmg_path}"

codesign_arguments=(--force --sign "${signing_identity}")
if [[ "${signing_identity}" != "-" ]]; then
  codesign_arguments+=(--timestamp)
fi
codesign "${codesign_arguments[@]}" "${dmg_path}"
codesign --verify --strict --verbose=2 "${dmg_path}"
printf '%s\n' "${dmg_path}"
