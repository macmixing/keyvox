#!/usr/bin/env bash
set -euo pipefail

MODEL_TRAINING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${MODEL_TRAINING_DIR}/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/keyvox-whisper-runtime-work.XXXXXX")"
OUTPUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/keyvox-whisper-runtime-output.XXXXXX")/keyvox-whisper-runtime-v1.7.5"
WHISPER_CPP_VERSION="${WHISPER_CPP_VERSION:-v1.7.5}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

export DEVELOPER_DIR
trap 'rm -rf "${WORK_DIR}" "$(dirname "${OUTPUT_DIR}")"' EXIT

if [[ ! -d "${DEVELOPER_DIR}" ]]; then
  echo "Xcode Beta not found at ${DEVELOPER_DIR}." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required." >&2
  exit 1
fi

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}" "${REPO_ROOT}/Artifacts"

git clone --depth 1 --branch "${WHISPER_CPP_VERSION}" https://github.com/ggml-org/whisper.cpp.git "${WORK_DIR}/whisper.cpp"

python3 - <<'PY' "${WORK_DIR}/whisper.cpp/src/coreml/whisper-encoder.mm"
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = "    config.computeUnits = MLComputeUnitsAll;\n"
new = """    if ([path_model_str containsString:@"/.cpu-fallback/"]) {
        config.computeUnits = MLComputeUnitsCPUOnly;
    } else {
        config.computeUnits = MLComputeUnitsAll;
    }
"""
if old not in source:
    raise SystemExit("Could not find Core ML computeUnits assignment to patch.")
path.write_text(source.replace(old, new))
PY

python3 - <<'PY' "${WORK_DIR}/whisper.cpp/build-xcframework.sh"
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()

start = 'echo "Building for visionOS'
end = 'echo "Setting up framework structures..."'
start_index = source.find(start)
end_index = source.find(end)
if start_index == -1 or end_index == -1 or start_index >= end_index:
    raise SystemExit("Could not trim non-KeyVox Apple platform builds.")
source = source[:start_index] + source[end_index:]

for line in [
    'setup_framework_structure "build-visionos" ${VISIONOS_MIN_OS_VERSION} "visionos"\n',
    'setup_framework_structure "build-visionos-sim" ${VISIONOS_MIN_OS_VERSION} "visionos"\n',
    'setup_framework_structure "build-tvos-sim" ${TVOS_MIN_OS_VERSION} "tvos"\n',
    'setup_framework_structure "build-tvos-device" ${TVOS_MIN_OS_VERSION} "tvos"\n',
    'combine_static_libraries "build-visionos" "Release-xros" "visionos" "false"\n',
    'combine_static_libraries "build-visionos-sim" "Release-xrsimulator" "visionos" "true"\n',
    'combine_static_libraries "build-tvos-sim" "Release-appletvsimulator" "tvos" "true"\n',
    'combine_static_libraries "build-tvos-device" "Release-appletvos" "tvos" "false"\n',
    '    -framework $(pwd)/build-visionos/framework/whisper.framework \\\n',
    '    -debug-symbols $(pwd)/build-visionos/dSYMs/whisper.dSYM \\\n',
    '    -framework $(pwd)/build-visionos-sim/framework/whisper.framework \\\n',
    '    -debug-symbols $(pwd)/build-visionos-sim/dSYMs/whisper.dSYM \\\n',
    '    -framework $(pwd)/build-tvos-device/framework/whisper.framework \\\n',
    '    -debug-symbols $(pwd)/build-tvos-device/dSYMs/whisper.dSYM \\\n',
    '    -framework $(pwd)/build-tvos-sim/framework/whisper.framework \\\n',
    '    -debug-symbols $(pwd)/build-tvos-sim/dSYMs/whisper.dSYM \\\n',
]:
    source = source.replace(line, "")

source = source.replace(
    '    -debug-symbols $(pwd)/build-macos/dSYMS/whisper.dSYM \\\n',
    '    -debug-symbols $(pwd)/build-macos/dSYMs/whisper.dSYM \\\n',
)

path.write_text(source)
PY

pushd "${WORK_DIR}/whisper.cpp" >/dev/null
./build-xcframework.sh
popd >/dev/null

rm -rf "${REPO_ROOT}/Artifacts/whisper.xcframework"
cp -R "${WORK_DIR}/whisper.cpp/build-apple/whisper.xcframework" "${REPO_ROOT}/Artifacts/whisper.xcframework"

rm -f "${OUTPUT_DIR}/whisper.xcframework.zip"
(
  cd "${REPO_ROOT}/Artifacts"
  zip -qry "${OUTPUT_DIR}/whisper.xcframework.zip" "whisper.xcframework"
)

CHECKSUM="$(swift package compute-checksum "${OUTPUT_DIR}/whisper.xcframework.zip")"
cat > "${OUTPUT_DIR}/artifact-manifest.json" <<JSON
{
  "runtimeID": "keyvox-whisper-runtime",
  "whisperCppVersion": "${WHISPER_CPP_VERSION}",
  "coreMLPolicy": "normal model paths use MLComputeUnitsAll; .cpu-fallback model paths use MLComputeUnitsCPUOnly",
  "swiftPMChecksum": "${CHECKSUM}"
}
JSON

echo "Wrote ${REPO_ROOT}/Artifacts/whisper.xcframework"
echo "Wrote ${OUTPUT_DIR}/whisper.xcframework.zip"
echo "SwiftPM checksum: ${CHECKSUM}"
