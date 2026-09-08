#!/usr/bin/env python3
"""Build and stage the pinned Swift Android engine and its actual ELF closure."""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--swift', required=True, type=pathlib.Path)
parser.add_argument('--sdk-libraries', required=True, type=pathlib.Path)
parser.add_argument('--ndk', required=True, type=pathlib.Path)
parser.add_argument('--whisper-prefix', required=True, type=pathlib.Path)
parser.add_argument('--scratch', required=True, type=pathlib.Path)
parser.add_argument('--qairt-root', type=pathlib.Path)
parser.add_argument('--qnn-plugin', type=pathlib.Path)
parser.add_argument('--configuration', choices=['debug', 'release'], default='debug')
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parent
if bool(args.qairt_root) != bool(args.qnn_plugin):
    raise SystemExit('--qairt-root and --qnn-plugin must be supplied together')
qnn_libraries = []
if args.qairt_root:
    runtime_lock = json.loads((root.parent / 'Native/WhisperQNN/runtime.lock.json').read_text())
    for name, digest in runtime_lock['files'].items():
        source = args.qairt_root / name
        if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != digest:
            raise SystemExit('QAIRT runtime does not match the verified version: ' + name)
    for name in ['LICENSE.pdf', 'QNN_NOTICE.txt']:
        if not (args.qairt_root / name).is_file():
            raise SystemExit('QAIRT license file required: ' + name)
    qnn_libraries = [args.qnn_plugin] + [args.qairt_root / 'lib/aarch64-android' / name
        for name in ['libQnnHtp.so', 'libQnnSystem.so', 'libQnnHtpV81Stub.so']]
    if args.qnn_plugin.name != 'libKeyVoxWhisperQnn.so':
        raise SystemExit('Expected libKeyVoxWhisperQnn.so')
version = subprocess.check_output([str(args.swift), '--version'], text=True)
if 'Swift version 6.3.3' not in version:
    raise SystemExit('The Android main-loop adapter requires Swift 6.3.3')
command = [str(args.swift), 'build', '--package-path', str(root / 'EngineBridge'),
    '--swift-sdk', 'aarch64-unknown-linux-android28', '--scratch-path', str(args.scratch),
    '--configuration', args.configuration,
    '-Xcc', '-I' + str(args.whisper_prefix / 'include'),
    '-Xlinker', '-L' + str(args.whisper_prefix / 'lib'), '-Xlinker', '-lc++_shared']
subprocess.run(command, check=True)
binary = pathlib.Path(subprocess.check_output(command + ['--show-bin-path'], text=True).strip())
toolchains = list((args.ndk / 'toolchains/llvm/prebuilt').glob('*'))
if len(toolchains) != 1:
    raise SystemExit('Expected one installed NDK host toolchain')
toolchain = toolchains[0]
readelf = toolchain / 'bin/llvm-readelf'
runtime = toolchain / 'sysroot/usr/lib/aarch64-linux-android'
system = {'libc.so', 'libm.so', 'libdl.so', 'liblog.so', 'libandroid.so', 'libz.so'}
if args.qairt_root:
    # Vendor RPC library is requested optionally in the app manifest, never bundled.
    system.add('libcdsprpc.so')
pending = [binary / 'libKeyVoxAndroidEngine.so'] + qnn_libraries
libraries = {}
while pending:
    library = pending.pop()
    if library.name in libraries:
        continue
    if args.qairt_root and library.is_relative_to(args.qairt_root) and str(library.relative_to(args.qairt_root)) not in runtime_lock['files']:
        raise SystemExit('Unreviewed QAIRT dependency: ' + str(library))
    libraries[library.name] = library
    elf = subprocess.check_output([str(readelf), '-d', str(library)], text=True)
    for name in re.findall(r'\(NEEDED\).*\[(.*?)\]', elf):
        if name in system or name in libraries:
            continue
        candidates = [directory / name for directory in [binary, args.sdk_libraries, runtime, args.whisper_prefix / 'lib'] + ([args.qairt_root / 'lib/aarch64-android'] if args.qairt_root else [])]
        found = next((item for item in candidates if item.is_file()), None)
        if found is None:
            raise SystemExit('Unresolved native library: ' + name)
        pending.append(found)
output = root / 'app/build/generated/engine'
# This directory contains only disposable output from this script.
if output.exists():
    shutil.rmtree(output)
jni = output / 'jniLibs/arm64-v8a'
assets = output / 'assets'
jni.mkdir(parents=True)
assets.mkdir()
inventory = []
for name, source in sorted(libraries.items()):
    shutil.copy2(source, jni / name)
    inventory.append({'name': name, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest()})
resources = assets / 'swift-resources'
resources.mkdir()
for source in sorted(binary.glob('*.resources')):
    shutil.copytree(source, resources / source.name)
if args.qairt_root:
    dsp = resources / 'KeyVoxQnnRuntime.resources'
    dsp.mkdir()
    for name in ['libQnnHtpV81Skel.so', 'libqnnhtpv81.cat']:
        source = args.qairt_root / 'lib/hexagon-v81/unsigned' / name
        shutil.copy2(source, dsp / name)
        inventory.append({'name': name, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest()})
identity = hashlib.sha256()
for source in sorted(resources.rglob('*')):
    if source.is_file():
        identity.update(str(source.relative_to(resources)).encode())
        identity.update(b'\0')
        identity.update(hashlib.sha256(source.read_bytes()).digest())
(assets / 'engine-resources-id').write_text(identity.hexdigest() + '\n')
licenses = assets / 'licenses'
shutil.copytree(root.parent / 'Tools/Licenses', licenses)
native_notices = args.whisper_prefix / 'share/licenses/keyvox-speech'
if not native_notices.is_dir():
    raise SystemExit('Native Whisper/NDK notices are required: ' + str(native_notices))
shutil.copytree(native_notices, licenses / 'Whisper-Native')
shutil.copy2(args.whisper_prefix / 'WHISPER-LICENSE', licenses / 'Whisper-Native/WHISPER-LICENSE')
if args.qairt_root:
    notices = licenses / 'Qualcomm-QAIRT'
    notices.mkdir()
    for name in ['LICENSE.pdf', 'QNN_NOTICE.txt']:
        shutil.copy2(args.qairt_root / name, notices / name)
(assets / 'native-libraries.json').write_text(json.dumps(inventory, indent=2) + '\n')
print('Staged', len(libraries), 'native libraries at', output)
