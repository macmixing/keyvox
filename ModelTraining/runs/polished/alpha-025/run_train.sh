#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

MODEL_TRAINING_ROOT="$(cd "$ROOT_DIR/../../.." && pwd)"
MODEL="${KEYVOX_FT_MODEL:-Qwen/Qwen2.5-0.5B-Instruct}"
DATA_DIR="$MODEL_TRAINING_ROOT/datasets/polished/alpha-025-continuation-money-boundaries"
ADAPTER_DIR="$MODEL_TRAINING_ROOT/artifacts/current/polished-lora-alpha-025/adapters/polished-alpha-025"
OUTPUT_DIR="$MODEL_TRAINING_ROOT/artifacts/current/polished-lora-alpha-025/outputs/polished-alpha-025"
RESUME_ADAPTER_FILE="${KEYVOX_RESUME_ADAPTER_FILE:-$MODEL_TRAINING_ROOT/artifacts/current/polished-lora-alpha-024/adapters/polished-alpha-024/adapters.safetensors}"
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

echo "Training Polished alpha-025 adapter..."
TRAIN_ARGS=(
    --model "$MODEL" \
    --train \
    --data "$DATA_DIR" \
    --adapter-path "$ADAPTER_DIR" \
    --config "$ROOT_DIR/train_config.yaml" \
    --iters "${KEYVOX_FT_ITERS:-60}" \
    --batch-size "${KEYVOX_FT_BATCH_SIZE:-1}" \
    --learning-rate "${KEYVOX_FT_LEARNING_RATE:-7e-7}" \
    --mask-prompt
)
if [[ -n "$RESUME_ADAPTER_FILE" ]]; then
    TRAIN_ARGS+=(--resume-adapter-file "$RESUME_ADAPTER_FILE")
fi
run_lora "${TRAIN_ARGS[@]}"

python3 - "$ADAPTER_DIR/adapter_config.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
config = json.loads(path.read_text(encoding="utf-8"))
config["lora_alpha"] = 512
config["r"] = 16
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
generate_case "reported_since_year_pair" "It feels like we've been doing this since twenty twelve, but it's only twenty eighteen."
generate_case "reported_since_question" "I can't believe we haven't done that since what, twenty twelve?"
generate_case "reported_movie_year" "I'm pretty sure that movie came out in twenty twelve. What do you think?"
generate_case "reported_seen_since" "I can't believe so much time has passed. I haven't seen you since like twenty twelve."
generate_case "reported_eighteen_year_old_glasses" "And it's funny because all of those tools I had years ago came in handy to restore an eighteen year old pair of glasses."
generate_case "age_compound_sweep" "The shop restored a thirteen year old frame, a fourteen year old lens kit, a fifteen year old case, a sixteen year old hinge, a seventeen year old bridge, an eighteen year old pair of glasses, and a nineteen year old receipt."
generate_case "eight_age_guard" "The archive included an eight year old pair of glasses, an eighteen year old pair of glasses, and eighty year old paperwork."
generate_case "spoken_year_sweep" "The archive includes twenty ten, twenty eleven, twenty twelve, twenty thirteen, twenty fourteen, twenty fifteen, twenty sixteen, twenty seventeen, twenty eighteen, and twenty nineteen."
generate_case "quantity_guard" "The team closed twenty two tickets, reviewed twenty eight screenshots, and ordered twenty five labels."
generate_case "reported_star_ratings" "I have like twelve five star ratings right now."
generate_case "reported_hundred_dollars_days" "I would have spent one hundred dollars seven days ago."
generate_case "reported_fifty_dollars_days" "I would have spent fifty dollars seven days ago."
generate_case "reported_four_dollars_days" "I would have spent four dollars six days ago."
generate_case "reported_twenty_five_dollars_days" "I probably spent twenty-five dollars three days ago."
generate_case "reported_ten_for_one_dollar" "I ended up getting ten for one dollar."
generate_case "reported_four_for_three_dollars" "I ended up getting four for three dollars."
generate_case "reported_money_multiplier_words" "I don't know, that's probably three dollars multiplied by four."
generate_case "reported_money_multiplier_symbols" "I don't know, that's probably 3 * 4 dollars."
generate_case "reported_cost_fifty_three_days" "It probably cost fifty dollars three days ago."
generate_case "existing_long_numeric_gauntlet" "Um hey team, I looked at the April twenty second launch notes, and there are like three things we need to clean up. Sarah and me was reviewing the checklist at eleven thirty, and we found two minor issues. I ain't worried about the build, but the screenshots still need a final pass.

Okay, so the customer paid one thousand two hundred dollars in twenty twenty four. They was asking whether the invoice, um, should show the discount as fifteen percent or as one hundred eighty dollars. I seen the same confusion last week, and we should make the update clear.

For follow up, please confirm the invoice, like send the April twenty second recap, and ask Jordan if the three screenshots are final. We should keep the tone professional but direct. I don't want the meaning to change."

echo "Done."
echo "Adapter: $ADAPTER_DIR"
echo "Outputs: $OUTPUT_DIR"
