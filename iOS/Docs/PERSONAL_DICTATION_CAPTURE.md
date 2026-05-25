# Personal Dictation Capture
**Last Updated: 2026-05-25**

## Purpose

Personal Dictation Capture records real KeyVox dictation examples from the iOS keyboard so rated before/after data can be reviewed, debugged, and used later for model or adapter training.

The capture flow is intentionally small:

1. Dictate normally from the KeyVox keyboard.
2. Let the app run the normal dictation, post-processing, and Vibes rewrite pipeline.
3. Rate only the visible Vibes result that was actually shown to the user.
4. Export the captured SQLite database or rated JSON from the containing app.

The goal is to collect real examples from normal use without adding a separate review app, dashboard, import flow, or training pipeline inside the product.

## What Gets Rated

Capture records are stored at the visible variant level. A variant is one concrete style result for one dictation, such as Casual or Polished.

`None` is not a rating target. Plain deterministic dictation output is useful context, but it is not training data for a Vibes rewrite result.

Paragraph/list-only changes with `None` are not rating targets either. When a paragraph or list long press re-renders the current real Vibe, that newly visible Vibe result becomes the active rating target.

Each real Vibe style can have its own rating for the same dictation:

- Casual can be rated good.
- Polished can be rated bad or good separately.
- Chill can be rated separately.
- Returning to an already rated style/result reuses the existing row and reflects its current rating.

## Keyboard Flow

The dictionary key is repurposed as the rating key. Caps Lock remains available in the previous dictionary-key position.

Rating key states:

- Inactive or rated: `checkmark.app`, normal key foreground.
- Unrated or re-armed: `checkmark.app.fill`, red.
- Disabled by keyboard state: no rating action should be taken.

Rating gestures:

- Tap marks the active or re-armed variant `good`.
- Long press marks the active or re-armed variant `bad`.
- Double tap clears the active rated variant back to `unrated`.
- If no active ratable variant exists, double tap re-arms the most recent unrated Vibes variant from SQLite.

The double-tap recovery path exists for normal keyboard interruptions. If the keyboard is dismissed after a Vibes output appears, double tap can re-arm the latest unrated Vibes result so it can still be rated.

## Vibes Switching

Normal insertion seeds the rating context from the latest dictation artifact.

If the inserted style is `None`, rating stays inactive.

If the inserted style is a real Vibe, the keyboard creates or selects an unrated variant row for the visible text and lights the rating key red.

When the Vibes key is long-pressed and the latest untouched insertion is replaced:

- Switching to `None` clears the active rating context.
- Switching to a real Vibe creates or selects that style/result variant.
- Switching from Casual to Polished creates a separate Polished row.
- Switching back to a previously rated Casual result restores that row's existing rating state.

Manual edits or host-app changes can invalidate the active insertion context. The latest unrated row remains recoverable through double tap.

## Data Model

The keyboard and containing app share one SQLite database in the app group container:

```text
personal-dictation-captures.sqlite
```

The primary table stores visible variants:

```text
capture_variants
```

Important fields:

- `capture_id`: stable dictation/session id from the latest artifact when available.
- `variant_id`: stable id for this visible style result.
- `style_identifier`: Vibe style, such as `casual`, `polished`, or `chill`.
- `source_text`: input text used for the Vibes transform.
- `visible_text`: final visible text being rated.
- `raw_dictation_text`: provider output captured from the dictation artifact.
- `base_text`: deterministic post-dictation processed text.
- `model_output_text`: raw local rewrite model output when available.
- `postprocessed_output_text`: final Vibes output after repair and guards.
- `rating`: `unrated`, `good`, or `bad`.
- `created_at`: row creation time.
- `rated_at`: rating time, if rated.
- `metadata_json`: coarse timing, adapter, mode, chunk, error, and app-version context.

A second table stores coarse rewrite traces:

```text
rewrite_traces
```

Rewrite traces allow the final response path to attach the raw model output and postprocessed result to later keyboard-created variant rows.

## Pipeline Trace Scope

Tracing is intentionally coarse.

The capture flow uses the existing `DictationUtteranceArtifact` for:

- raw dictation text
- base post-processed text
- selected text
- deterministic variants
- selected style
- timing metadata

The containing app also records:

- raw local model output before final repair
- final style rewrite output after repair/guards
- basic rewrite metadata

The system does not trace every normalizer, factual repair step, or guard rule individually. If deeper debugging is needed later, add targeted instrumentation at the specific pipeline boundary being investigated.

## Export

The containing app Settings screen has a Personal Capture section with two export actions:

- SQLite exports the raw database file.
- JSON exports generated training/review JSON.

JSON export includes rated rows by default. Unrated rows stay in SQLite so they remain available for debugging and double-tap recovery, but they do not enter the default JSON dataset.

There is no import flow, no range picker, and no dashboard.

## Current Validation Notes

The capture flow has been manually verified with:

- Casual rating from normal dictation insertion.
- Polished rating after Vibes long-press replacement.
- Keyboard dismissal followed by double-tap recovery.
- Long dictation containing paragraph text and a numbered list.
- JSON export containing separate Casual and Polished `good` rows under the same `capture_id`.
- Captured `model_output_text`, `postprocessed_output_text`, and `visible_text` for rated variants.

The most important behavior from the long-dictation recovery test was that double tap re-armed the latest unrated Polished variant instead of re-rating the already rated Casual variant.

## File Ownership

Main implementation points:

- `KeyVox iOS/App/Debug/PersonalDictationCaptureStore.swift`
- `KeyVox Keyboard/Core/Dictation/KeyboardDictationRatingController.swift`
- `KeyVox Keyboard/Core/Dictation/KeyboardDictationChangeController.swift`
- `KeyVox Keyboard/App/KeyboardViewController.swift`
- `KeyVox Keyboard/App/KeyboardViewController+PresentationLifecycle.swift`
- `KeyVox Keyboard/Views/KeyboardRootView.swift`
- `KeyVox Keyboard/Core/KeyboardTopRowAccessoryLayout.swift`
- `KeyVox iOS/Core/StyleRewrite/LocalStyleRewriteTextTransformer.swift`
- `KeyVox iOS/Core/StyleRewrite/StyleRewritePipelineCoordinator.swift`
- `KeyVox iOS/App/Composition/AppServiceRegistry.swift`
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView.swift`
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView+General.swift`
- `KeyVox iOS/Views/Components/AppActivityShareSheet.swift`

Keep future changes narrow. This feature should stay as a small app/keyboard-local debug capture tool, not a reusable persistence framework or a second analytics system.
