#!/usr/bin/env python3
"""Reject native exports/dependencies that could collide with Whisper's GGML."""
import pathlib
import subprocess
import sys

library = pathlib.Path(sys.argv[1])
ndk = pathlib.Path(sys.argv[2])
readelfs = list(ndk.glob("toolchains/llvm/prebuilt/*/bin/llvm-readelf"))
if len(readelfs) != 1:
    raise SystemExit("Expected one NDK host toolchain")
report = subprocess.check_output(
    [str(readelfs[0]), "--wide", "--dynamic", "--dyn-syms", str(library)], text=True
)
exports = set()
dependencies = set()
for line in report.splitlines():
    if "(NEEDED)" in line:
        dependencies.add(line.split("[", 1)[1].split("]", 1)[0])
    fields = line.split()
    if len(fields) >= 8 and fields[4] in {"GLOBAL", "WEAK"} and fields[6] != "UND":
        exports.add(fields[7])
required = {"parakeet_capi_load", "parakeet_capi_free", "parakeet_capi_abi_version",
            "parakeet_capi_transcribe_pcm_lang", "parakeet_capi_free_string"}
if not required <= exports or any(not name.startswith("parakeet_capi_") for name in exports):
    raise SystemExit(f"Unexpected native exports: {sorted(exports)}")
if dependencies != {"libc.so", "libm.so", "libdl.so", "libc++_shared.so"}:
    raise SystemExit(f"Unexpected native dependencies: {sorted(dependencies)}")
print(f"Verified {len(exports)} isolated C exports and {sorted(dependencies)}")
