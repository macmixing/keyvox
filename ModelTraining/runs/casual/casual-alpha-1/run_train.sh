#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

MODEL_TRAINING_ROOT="$(cd "$ROOT_DIR/../../.." && pwd)"
MODEL="${KEYVOX_FT_MODEL:-Qwen/Qwen2.5-0.5B-Instruct}"
DATA_DIR="$MODEL_TRAINING_ROOT/datasets/casual/casual-alpha-1-base"
ADAPTER_DIR="$MODEL_TRAINING_ROOT/artifacts/current/casual-lora-alpha-1/adapters/casual-alpha-1"
OUTPUT_DIR="$MODEL_TRAINING_ROOT/artifacts/current/casual-lora-alpha-1/outputs/casual-alpha-1"
SHORT_PROMPT="$(cat "$MODEL_TRAINING_ROOT/prompts/casual/casual_runtime_short.txt")"

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

echo "Training Casual alpha-1 adapter..."
run_lora \
    --model "$MODEL" \
    --train \
    --data "$DATA_DIR" \
    --adapter-path "$ADAPTER_DIR" \
    --config "$ROOT_DIR/train_config.yaml" \
    --iters "${KEYVOX_FT_ITERS:-350}" \
    --batch-size "${KEYVOX_FT_BATCH_SIZE:-1}" \
    --learning-rate "${KEYVOX_FT_LEARNING_RATE:-1e-5}" \
    --mask-prompt

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
        --max-tokens 160 \
        --temp 0 > "$OUTPUT_DIR/$name.txt"
}

echo "Generating comparison samples with short prompt..."
generate_case "remove_filler_keep_like" "Hey, um, like are you coming over later?"
generate_case "preserve_bad_grammar" "What you be doing after work?"
generate_case "preserve_aint" "I ain't doing that today."
generate_case "preserve_profanity" "Why the fuck is this button still weird?"
generate_case "list_cleanup" "I need groceries:

1. Um apples
2. Like bananas
3. Uh grapes"
generate_case "paragraph_cleanup" "Um I tested this for a little bit, and like it mostly works.

Uh the second paragraph should stay separate and keep the same meaning."
generate_case "long_gauntlet" "Um okay, like I tested the adapter for 20 minutes, and I ain't saying it's perfect. Sarah and me was trying a few weird cases, and what you be doing matters less than whether the words stay put.

Uh the list still needs to work:

1. Like apples
2. Um bananas
3. Fucking grapes

Hm the final note is that the invoice shows \$180, the date is April 22nd, and the follow up is at 11:30."

echo "Done."
echo "Adapter: $ADAPTER_DIR"
echo "Outputs: $OUTPUT_DIR"
