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
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parent
version = subprocess.check_output([str(args.swift), '--version'], text=True)
if 'Swift version 6.3.3' not in version:
    raise SystemExit('The Android main-loop adapter requires Swift 6.3.3')
command = [str(args.swift), 'build', '--package-path', str(root / 'EngineBridge'),
    '--swift-sdk', 'aarch64-unknown-linux-android28', '--scratch-path', str(args.scratch),
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
pending = [binary / 'libKeyVoxAndroidEngine.so']
libraries = {}
while pending:
    library = pending.pop()
    if library.name in libraries:
        continue
    libraries[library.name] = library
    elf = subprocess.check_output([str(readelf), '-d', str(library)], text=True)
    for name in re.findall(r'\(NEEDED\).*\[(.*?)\]', elf):
        if name in system or name in libraries:
            continue
        candidates = [directory / name for directory in [binary, args.sdk_libraries, runtime, args.whisper_prefix / 'lib']]
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
(assets / 'native-libraries.json').write_text(json.dumps(inventory, indent=2) + '\n')
print('Staged', len(libraries), 'native libraries at', output)
