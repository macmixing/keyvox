#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

MODEL_TRAINING_ROOT="$(cd "$ROOT_DIR/../../.." && pwd)"
MODEL="${KEYVOX_FT_MODEL:-Qwen/Qwen2.5-0.5B-Instruct}"
DATA_DIR="$MODEL_TRAINING_ROOT/datasets/polished/alpha-019-continuation-numeric-paragraphs"
ADAPTER_DIR="$MODEL_TRAINING_ROOT/artifacts/archive/polished-lora-alpha-019/adapters/polished-alpha-019"
OUTPUT_DIR="$MODEL_TRAINING_ROOT/artifacts/archive/polished-lora-alpha-019/outputs/polished-alpha-019"
RESUME_ADAPTER_FILE="${KEYVOX_RESUME_ADAPTER_FILE:-$MODEL_TRAINING_ROOT/artifacts/rejected/polished-lora-alpha-018/adapters/polished-alpha-018/adapters.safetensors}"
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

echo "Training Polished alpha-019 adapter..."
TRAIN_ARGS=(
    --model "$MODEL" \
    --train \
    --data "$DATA_DIR" \
    --adapter-path "$ADAPTER_DIR" \
    --config "$ROOT_DIR/train_config.yaml" \
    --iters "${KEYVOX_FT_ITERS:-150}" \
    --batch-size "${KEYVOX_FT_BATCH_SIZE:-1}" \
    --learning-rate "${KEYVOX_FT_LEARNING_RATE:-2e-6}" \
    --mask-prompt
)
if [[ -n "$RESUME_ADAPTER_FILE" ]]; then
    TRAIN_ARGS+=(--resume-adapter-file "$RESUME_ADAPTER_FILE")
fi
run_lora "${TRAIN_ARGS[@]}"

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
        --max-tokens 128 \
        --temp 0 > "$OUTPUT_DIR/$name.txt"
}

echo "Generating comparison samples with short prompt..."
generate_case "filler_after_punctuation" "Hey, what's going on? Um, are you having any problems?"
generate_case "meaning_preservation" "I don't know why, um, you're acting like such a fucking idiot, but can you like please um stop?"
generate_case "recent_live_failure" "Hey, um like what are you um doing later if you like I don't know, you know. You know what I mean?"
generate_case "numbered_list" "I need to pick up a couple of things from the store. Um:

1. Apples
2. Bananas
3. Grapes"
generate_case "minimal_edit" "I want this to feel cleaner but still sound like me."
generate_case "large_number" "The budget is five thousand twenty two dollars, and the backup estimate is six thousand one hundred."
generate_case "quantity_list" "Um remind me to order two cases of water, thirty six labels, and one hundred envelopes."
generate_case "long_status" "For the internal recap, um, we shipped the first pass on Monday, reviewed twenty seven pieces of feedback on Tuesday, fixed the top five issues on Wednesday, and by Friday the average rewrite time had dropped from one point two seconds to zero point six seconds."
generate_case "bad_grammar_be" "How you be doing today?"
generate_case "bad_grammar_was" "Sarah and me was going to lunch, but they was running late."
generate_case "bad_grammar_aint" "I ain't doing that, and that ain't nothing."
generate_case "numeric_list_quantities" "I need groceries:

1. Um apples
2. Like two cartons of eggs
3. Uh three bags of rice"
generate_case "numeric_minor_issues" "Please clean this up for a client update. Um we are still waiting on the final assets, but engineering finished the integration, QA found two minor issues, and the earliest realistic ship date is June fifth unless the review takes longer than expected."
generate_case "paragraph_preserve_statement" "I guess I never really tested this out, but I should try.

We just really need to observe the results."
generate_case "paragraph_preserve_question" "I guess I never really tested to see how this was working.

Should we try something later?"

echo "Done."
echo "Adapter: $ADAPTER_DIR"
echo "Outputs: $OUTPUT_DIR"
