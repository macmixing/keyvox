#!/usr/bin/env python3
"""Verify, preserve, and install the NPU keyboard APK on a shared device."""

import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import zipfile


root = pathlib.Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--adb', required=True, type=pathlib.Path)
parser.add_argument('--java-home', required=True, type=pathlib.Path)
parser.add_argument('--serial', required=True)
parser.add_argument(
    '--apk',
    type=pathlib.Path,
    default=root / 'app/build/outputs/apk/debug/app-debug.apk',
)
args = parser.parse_args()

required_entries = {
    'lib/arm64-v8a/libKeyVoxAndroidEngine.so',
    'lib/arm64-v8a/libKeyVoxWhisperQnn.so',
    'lib/arm64-v8a/libQnnHtp.so',
    'lib/arm64-v8a/libQnnSystem.so',
    'lib/arm64-v8a/libQnnHtpV81Stub.so',
    'assets/swift-resources/KeyVoxQnnRuntime.resources/libQnnHtpV81Skel.so',
    'assets/swift-resources/KeyVoxQnnRuntime.resources/libqnnhtpv81.cat',
    'assets/licenses/Qualcomm-QAIRT/LICENSE.pdf',
    'assets/licenses/Qualcomm-QAIRT/QNN_NOTICE.txt',
    'assets/licenses/WHISPER-MODEL-LICENSE.txt',
    'assets/licenses/Whisper-QNN/Eigen-MPL-2.0.txt',
    'assets/licenses/Whisper-QNN/Eigen-SOURCE-NOTICE.txt',
    'assets/licenses/Whisper-QNN/PROVENANCE.md',
    'assets/licenses/Whisper-QNN/Qualcomm-Export-BSD-3-Clause.txt',
    'assets/licenses/Whisper-QNN/Transformers-Apache-2.0.txt',
    'assets/licenses/runtime-models.lock.json',
    'assets/engine-profile.json',
}
integrity_entries = {
    'libKeyVoxWhisperQnn.so': 'lib/arm64-v8a/libKeyVoxWhisperQnn.so',
    'libQnnHtp.so': 'lib/arm64-v8a/libQnnHtp.so',
    'libQnnSystem.so': 'lib/arm64-v8a/libQnnSystem.so',
    'libQnnHtpV81Stub.so': 'lib/arm64-v8a/libQnnHtpV81Stub.so',
    'libQnnHtpV81Skel.so': (
        'assets/swift-resources/KeyVoxQnnRuntime.resources/libQnnHtpV81Skel.so'
    ),
    'libqnnhtpv81.cat': (
        'assets/swift-resources/KeyVoxQnnRuntime.resources/libqnnhtpv81.cat'
    ),
}

if not args.apk.is_file():
    raise SystemExit('APK does not exist: ' + str(args.apk))
with zipfile.ZipFile(args.apk) as archive:
    corrupt_entry = archive.testzip()
    if corrupt_entry:
        raise SystemExit('Refusing to install corrupt APK entry: ' + corrupt_entry)
    entries = set(archive.namelist())
    missing = sorted(required_entries - entries)
    if missing:
        raise SystemExit('Refusing to install APK without verified NPU payload: ' + ', '.join(missing))
    profile = json.loads(archive.read('assets/engine-profile.json'))
    inventory = {
        item['name']: item['sha256']
        for item in json.loads(archive.read('assets/native-libraries.json'))
    }
    for name, entry in integrity_entries.items():
        actual = hashlib.sha256(archive.read(entry)).hexdigest()
        if inventory.get(name) != actual:
            raise SystemExit('Refusing to install APK with mismatched NPU payload: ' + name)
if profile != {'profile': 'npu-device', 'configuration': 'release', 'qnn': True}:
    raise SystemExit('Refusing to install APK without the release npu-device profile')

build_tools = args.adb.parent.parent / 'build-tools'
versions = sorted(
    (directory for directory in build_tools.iterdir() if directory.is_dir()),
    key=lambda directory: tuple(int(part) for part in re.findall(r'\d+', directory.name)),
    reverse=True,
)
tools = next((directory for directory in versions
              if (directory / 'aapt2').is_file() and (directory / 'apksigner').is_file()), None)
if tools is None:
    raise SystemExit('Android aapt2 and apksigner are required to verify the APK')
badging = subprocess.check_output([str(tools / 'aapt2'), 'dump', 'badging', str(args.apk)], text=True)
package = re.search(r"^package: name='([^']+)'", badging)
if package is None or package.group(1) != 'org.keyvox.android':
    raise SystemExit('Refusing to install APK with unexpected package identity')
environment = os.environ.copy()
environment['JAVA_HOME'] = str(args.java_home)
subprocess.run(
    [str(tools / 'apksigner'), 'verify', '--verbose', str(args.apk)],
    check=True,
    env=environment,
)

artifact_directory = root / '.device-artifacts'
artifact_directory.mkdir(exist_ok=True)
digest = hashlib.sha256(args.apk.read_bytes()).hexdigest()
preserved_apk = artifact_directory / ('keyvox-npu-' + digest + '.apk')
if not preserved_apk.exists():
    temporary_apk = artifact_directory / (preserved_apk.name + '.pending')
    shutil.copy2(args.apk, temporary_apk)
    if hashlib.sha256(temporary_apk.read_bytes()).hexdigest() != digest:
        raise SystemExit('Preserved APK copy failed integrity verification')
    temporary_apk.replace(preserved_apk)

subprocess.run([
    str(args.adb), '-s', args.serial, 'install', '-r', str(preserved_apk)
], check=True)
marker = artifact_directory / 'current-npu.sha256'
pending_marker = artifact_directory / 'current-npu.sha256.pending'
pending_marker.write_text(digest + '  ' + preserved_apk.name + '\n')
pending_marker.replace(marker)
print('Installed verified NPU APK; preserved SHA-256', digest)
