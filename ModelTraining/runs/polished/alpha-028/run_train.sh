#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

MODEL_TRAINING_ROOT="$(cd "$ROOT_DIR/../../.." && pwd)"
MODEL="${KEYVOX_FT_MODEL:-Qwen/Qwen2.5-0.5B-Instruct}"
DATA_DIR="$MODEL_TRAINING_ROOT/datasets/polished/alpha-028-continuation-casual-reductions"
ADAPTER_DIR="$MODEL_TRAINING_ROOT/artifacts/current/polished-lora-alpha-028/adapters/polished-alpha-028"
OUTPUT_DIR="$MODEL_TRAINING_ROOT/artifacts/current/polished-lora-alpha-028/outputs/polished-alpha-028"
RESUME_ADAPTER_FILE="${KEYVOX_RESUME_ADAPTER_FILE:-$MODEL_TRAINING_ROOT/artifacts/current/polished-lora-alpha-027/adapters/polished-alpha-027/adapters.safetensors}"
SHORT_PROMPT="$(cat "$MODEL_TRAINING_ROOT/prompts/polished/polished_runtime_short.txt")"

mkdir -p "$ADAPTER_DIR" "$OUTPUT_DIR"

run_lora() {
    if command -v mlx_lm.lora >/dev/null 2>&1; then
        mlx_lm.lora "$@"
    else
        python3 -m mlx_lm lora "$@"
    fi
}

run_generate() {
    if command -v mlx_lm.generate >/dev/null 2>&1; then
        mlx_lm.generate "$@"
    else
        python3 -m mlx_lm generate "$@"
    fi
}

echo "Generating dataset..."
python3 "$ROOT_DIR/scripts/generate_dataset.py"

echo "Validating dataset..."
python3 "$ROOT_DIR/scripts/validate_dataset.py" "$DATA_DIR"

echo "Training Polished alpha-028 adapter..."
TRAIN_ARGS=(
    --model "$MODEL" \
    --train \
    --data "$DATA_DIR" \
    --adapter-path "$ADAPTER_DIR" \
    --config "$ROOT_DIR/train_config.yaml" \
    --iters "${KEYVOX_FT_ITERS:-230}" \
    --batch-size "${KEYVOX_FT_BATCH_SIZE:-1}" \
    --learning-rate "${KEYVOX_FT_LEARNING_RATE:-2e-6}" \
    --mask-prompt
)
if [[ -n "$RESUME_ADAPTER_FILE" ]]; then
    TRAIN_ARGS+=(--resume-adapter-file "$RESUME_ADAPTER_FILE")
fi
run_lora "${TRAIN_ARGS[@]}"

python3 - "$ADAPTER_DIR/adapter_config.json" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
config = json.loads(path.read_text(encoding="utf-8"))
train_config_path = Path.cwd() / "train_config.yaml"
train_config = train_config_path.read_text(encoding="utf-8")
rank_match = re.search(r"(?m)^\s*rank:\s*(\d+)\s*$", train_config)
if not rank_match:
    raise SystemExit(f"Could not parse LoRA rank from {train_config_path}")

rank = int(rank_match.group(1))
# KeyVox validates GGUF runtime behavior at adapter scale 32, even when MLX
# training scale is higher. llama.cpp applies adapter.lora.alpha / rank.
runtime_scale = 32.0
computed_alpha = runtime_scale * rank
config["lora_alpha"] = int(computed_alpha) if computed_alpha.is_integer() else computed_alpha
config["r"] = rank
config["base_model_name_or_path"] = "Qwen/Qwen2.5-0.5B-Instruct"
path.write_text(json.dumps(config, indent=4) + "\n", encoding="utf-8")
PY

echo "Running held-out test..."
run_lora \
    --model "$MODEL" \
    --adapter-path "$ADAPTER_DIR" \
    --data "$DATA_DIR" \
    --test | tee "$OUTPUT_DIR/test.log"

generate_case() {
    local name="$1"
    local user_text="$2"
    local prompt
    prompt="<|im_start|>system
$SHORT_PROMPT<|im_end|>
<|im_start|>user
$user_text<|im_end|>
<|im_start|>assistant
"
    run_generate \
        --model "$MODEL" \
        --adapter-path "$ADAPTER_DIR" \
        --prompt "$prompt" \
        --max-tokens 256 \
        --temp 0 > "$OUTPUT_DIR/$name.txt"
}

echo "Generating comparison samples with short prompt..."
generate_case "reported_gotta" "I gotta get there tomorrow at two."
generate_case "reported_mixed" "Hey, what's up? I'm gonna do this, but do you wanna go there? I gotta get there tomorrow at two."
generate_case "sentence_start_gonna" "Gonna be late tonight, sorry."
generate_case "sentence_start_wanna" "Wanna come over later?"
generate_case "question_wanna" "What do you wanna eat tonight?"
generate_case "gotta_stop_meaning" "We gotta stop at the store on the way because I'm gonna need snacks."
generate_case "other_reductions" "Lemme know if you need anything. Gimme a minute, I'm kinda busy."
generate_case "control_going_to" "I'm going to the store."
generate_case "control_got_to" "I got to meet the band after the show."
generate_case "reported_since_year_pair" "It feels like we've been doing this since twenty twelve, but it's only twenty eighteen."
generate_case "reported_hundred_dollars_days" "I would have spent a hundred dollars seven days ago."
generate_case "reported_address_ordinal" "She said her address was eleven twenty five North Twelfth Street."
generate_case "bad_rating_call_you" "Do you think now is a good time to call you?"

echo "Done."
echo "Adapter: $ADAPTER_DIR"
echo "Outputs: $OUTPUT_DIR"
