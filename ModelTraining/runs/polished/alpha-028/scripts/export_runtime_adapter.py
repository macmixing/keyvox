#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path

from safetensors.numpy import load_file, save_file


MLX_ADAPTER_FILE = "adapters.safetensors"
PEFT_ADAPTER_FILE = "adapter_model.safetensors"


def write_peft_adapter(adapter_dir: Path) -> None:
    mlx_tensors = load_file(str(adapter_dir / MLX_ADAPTER_FILE))
    peft_tensors = {}
    for name, tensor in mlx_tensors.items():
        if name.endswith(".lora_a"):
            peft_name = name.removesuffix(".lora_a") + ".lora_A.weight"
        elif name.endswith(".lora_b"):
            peft_name = name.removesuffix(".lora_b") + ".lora_B.weight"
        else:
            raise ValueError(f"unexpected adapter tensor: {name}")
        peft_tensors[peft_name] = tensor.T.copy()
    save_file(peft_tensors, str(adapter_dir / PEFT_ADAPTER_FILE))


def main() -> int:
    parser = argparse.ArgumentParser(description="Export an MLX LoRA checkpoint as a KeyVox runtime GGUF adapter.")
    parser.add_argument("--adapter-dir", type=Path, required=True)
    parser.add_argument("--base-model-dir", type=Path, required=True)
    parser.add_argument("--llama-cpp-dir", type=Path, required=True)
    parser.add_argument("--outfile", type=Path, required=True)
    args = parser.parse_args()

    write_peft_adapter(args.adapter_dir)
    return subprocess.call([
        sys.executable,
        str(args.llama_cpp_dir / "convert_lora_to_gguf.py"),
        "--base", str(args.base_model_dir),
        "--outtype", "f32",
        "--outfile", str(args.outfile),
        str(args.adapter_dir),
    ])


if __name__ == "__main__":
    raise SystemExit(main())
