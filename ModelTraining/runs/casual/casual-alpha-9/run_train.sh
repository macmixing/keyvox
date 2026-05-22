#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

MODEL_TRAINING_ROOT="$(cd "$ROOT_DIR/../../.." && pwd)"
MODEL="${KEYVOX_FT_MODEL:-Qwen/Qwen2.5-0.5B-Instruct}"
DATA_DIR="$MODEL_TRAINING_ROOT/datasets/casual/casual-alpha-9-continuation-rating-unlearn"
ADAPTER_DIR="$MODEL_TRAINING_ROOT/artifacts/current/casual-lora-alpha-9/adapters/casual-alpha-9"
OUTPUT_DIR="$MODEL_TRAINING_ROOT/artifacts/current/casual-lora-alpha-9/outputs/casual-alpha-9"
RESUME_ADAPTER_FILE="${KEYVOX_RESUME_ADAPTER_FILE:-$MODEL_TRAINING_ROOT/artifacts/current/casual-lora-alpha-8/adapters/casual-alpha-8/adapters.safetensors}"
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

echo "Training Casual alpha-9 adapter..."
TRAIN_ARGS=(
    --model "$MODEL" \
    --train \
    --data "$DATA_DIR" \
    --adapter-path "$ADAPTER_DIR" \
    --config "$ROOT_DIR/train_config.yaml" \
    --iters "${KEYVOX_FT_ITERS:-120}" \
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
generate_case "adjacent_years" "The audit started in twenty eighteen and wrapped up in twenty nineteen."
generate_case "quantity_guard" "The team closed twenty two tickets, reviewed twenty eight screenshots, and ordered twenty five labels."
generate_case "reported_fifty_dollars_days" "I would have spent fifty dollars seven days ago."
generate_case "reported_hundred_dollars_days" "I would have spent one hundred dollars seven days ago."
generate_case "reported_forty_three_dollars_days" "I would have spent forty-three dollars seven days ago."
generate_case "reported_ten_for_one_dollar" "I ended up getting ten for one dollar."
generate_case "reported_cost_fifty_dollars_days" "It probably would have cost fifty dollars three days ago."
generate_case "reported_money_multiplier_words" "Yeah, that was what? Fifty dollars multiplied by three?"
generate_case "reported_money_multiplier_symbols_fifty" "Yeah, that was 3 * 50 dollars."
generate_case "reported_money_multiplier_symbols_fifty_seven" "What yeah, that was 3 * 57 dollars."
generate_case "reported_negated_concert_aint" "Tell John the concert ain't five dollars, but it'll be three dollars."
generate_case "reported_negated_concert_shortened" "Tell John the concert is three dollars, not five dollars."
generate_case "reported_twenty_five_money_time" "Um I'm pretty sure that's like twenty-five dollars and starts at three thirty."
generate_case "reported_twenty_money_time" "Um I'm pretty sure that's like twenty dollars and starts at three thirty."
generate_case "negated_like_money" "I'm pretty sure that's like twenty-five dollars, not twenty dollars."
generate_case "variant_money_time" "Yeah, tickets are twenty seven dollars and doors open at eleven fifteen."
generate_case "reported_aint_twenty_five_money_time" "I'm pretty sure that ain't twenty-five dollars, but I definitely know it starts at three thirty."
generate_case "reported_aint_thirty_five_money_time" "I'm pretty sure that ain't thirty-five dollars, but I definitely know it starts at five thirty."
generate_case "variant_isnt_forty_money_time" "I'm pretty sure that isn't forty dollars, but I definitely know it starts at six fifteen."
generate_case "variant_price_not_forty_five_money_time" "The price is not forty-five dollars, and the start time is seven forty five."
generate_case "variant_plain_ticket_time" "The ticket price should be fifty dollars, and the event starts at eight thirty."
generate_case "reported_address_east_clifford" "Meet me at 655 East Clifford Drive."
generate_case "reported_address_north_washington" "Meet me at 652 North Washington Street."
generate_case "reported_address_west_general" "Meet me at 852 West General Street."
generate_case "reported_spoken_address_east_clifford_compound" "Meet me at six fifty five East Clifford Drive."
generate_case "reported_spoken_address_east_clifford_digits" "Meet me at six five five East Clifford Drive."
generate_case "reported_spoken_address_north_washington" "Meet me at six fifty two North Washington Street."
generate_case "reported_spoken_address_west_general" "Meet me at eight fifty two West General Street."
generate_case "reported_comma_address_north_washington" "Meet me at 1,152 North Washington Street."
generate_case "reported_spoken_four_digit_address_north_washington" "Meet me at eleven fifty two North Washington Street."
generate_case "variant_comma_address_east_clifford" "Meet me at 1,155 East Clifford Drive."
generate_case "variant_comma_address_west_general" "Send it to 1,034 West General Street."
generate_case "variant_spoken_four_digit_address_east_clifford" "Meet me at eleven fifty five East Clifford Drive."
generate_case "variant_spoken_four_digit_address_west_general" "Meet me at ten thirty four West General Street."
generate_case "variant_address_south_maple" "Drop the package at 734 South Maple Avenue."
generate_case "variant_spoken_address_south_maple" "Drop the package at seven three four South Maple Avenue."
generate_case "variant_address_with_time_after" "Meet me at 655 East Clifford Drive at three thirty."
generate_case "variant_time_before_address" "The appointment is at three thirty at 652 North Washington Street."
generate_case "variant_spoken_address_with_time_after" "Meet me at six fifty five East Clifford Drive at three thirty."
generate_case "variant_time_before_spoken_address" "The appointment is at three thirty at six five two North Washington Street."
generate_case "variant_spoken_four_digit_address_with_time" "Meet me at eleven fifty two North Washington Street at three thirty."
generate_case "casual_voice_gauntlet" "Um okay, like I tested the adapter for 20 minutes, and I ain't saying it's perfect. Sarah and me was trying a few weird cases, and what you be doing matters less than whether the words stay put.

Uh the list still needs to work:

1. Like apples
2. Um bananas
3. Fucking grapes

Hm the final note is that the invoice shows \$180, the date is April 22nd, and the follow up is at 11:30."

echo "Done."
echo "Adapter: $ADAPTER_DIR"
echo "Outputs: $OUTPUT_DIR"
