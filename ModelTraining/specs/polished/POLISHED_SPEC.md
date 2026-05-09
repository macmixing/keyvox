# KeyVox Polished LoRA Spec

## Goal

Teach `Qwen2.5-0.5B-Instruct` to rewrite dictated text in the KeyVox Polished style with a much shorter runtime prompt.

The adapter should learn the recurring editorial behavior currently carried by the prompt:

- remove spoken filler and disfluency
- repair clear dictation artifacts
- convert spoken numbers into numeric form where appropriate
- preserve meaning, tone, intensity, and structure
- avoid over-editing
- output only the rewritten text

The target runtime shape is:

```text
base model + Polished LoRA + short prompt
```

## Style Definition

Polished is clean, composed copyediting that still sounds like the speaker.

It should make text easier to read without making it corporate, generic, formal by default, or emotionally flatter than the original.

Polished should feel like a careful editor cleaned up the dictated text, not like a different person rewrote it.

## Input Types To Cover

The dataset must include many text shapes, not just one style of writing:

- short text messages
- direct questions
- requests
- apologies
- frustrated messages
- emotionally intense messages
- casual but cleaned-up notes
- longer paragraphs
- emails without invented greetings or sign-offs
- numbered lists
- bulleted lists
- inline lists
- fragments
- repeated starts
- punctuation-light dictation
- names, dates, times, prices, measurements, counts, URLs, emails, emoji, and code-like text

## Required Behavior

### Filler And Disfluency

Remove non-meaningful spoken filler throughout the input:

- um
- uh
- er
- uh-huh
- hm
- hmm
- filler use of like
- you know
- I mean
- repeated starts
- accidental repeated words

Keep every meaningful word around removed filler.

When filler appears after punctuation, remove only the filler and keep the sentence that follows it.

When a sentence begins with filler, remove the filler and keep the sentence.

### Meaning Preservation

Preserve the speaker's actual intent.

Keep:

- emotional force
- uncertainty
- directness
- frustration
- profanity when it carries tone or meaning
- personal phrasing when it is already readable
- names
- facts
- numbers
- dates
- times
- prices
- measurements
- counts
- URLs
- email addresses
- emoji
- symbols
- code-like text

### Copyediting

Fix clear dictated-text issues:

- punctuation
- casing
- repeated words
- obvious grammar mistakes
- subject-verb agreement
- dictated dates
- dictated times
- dictated money
- dictated numbers
- spacing after removed filler

Use the smallest edit that makes the text polished.

### Numeric Normalization

Convert spoken numbers into numeric form when that improves clarity or matches normal written usage.

Examples:

- five hundred -> 500
- twenty twenty four -> 2024
- five thousand twenty two -> 5,022
- one hundred twenty dollars -> $120
- three thirty -> 3:30
- May third -> May 3rd

Do not force numerals where words are clearly more natural, idiomatic, or part of a name/title.

### Structure Preservation

Preserve existing structure.

If the input has paragraphs, keep paragraphs.

If the input has a numbered list, keep the numbered list.

If the input has bullets, keep bullets.

If the input has an inline list, keep it inline unless punctuation clearly calls for a formatted list.

Do not flatten lists into a sentence unless the input was already a sentence.

## Forbidden Behavior

The adapter must not:

- summarize
- soften meaning
- censor profanity
- remove an emotional clause
- remove a request
- remove uncertainty
- invent details
- answer the user
- add commentary
- add labels
- add headings
- add greetings
- add sign-offs
- reorder content
- split content unnecessarily
- merge separate structured items
- duplicate phrases
- make every message sound like an email
- turn casual text into corporate language
- preserve filler just because it appears after punctuation

## Edit Strength

Polished should usually be a medium edit, not too heavy but not too light.

Use heavier edits only when the original has obvious dictation damage.

Already good text should receive minimal changes or no changes.

## Dataset Principle

The dataset teaches allowed edits, not topics.

Examples should vary topics enough to avoid overfitting, but coverage should be organized around edit patterns:

- filler removal
- punctuation repair
- structure preservation
- meaning preservation
- minimal edits
- profanity preservation
- list preservation
- requests
- questions
- notes
- messages
- numeric normalization

## Evaluation Priorities

The eval set should be harsher than the training set.

It must include cases that previously failed:

- filler after punctuation
- filler at the beginning of a sentence
- list flattening
- profanity causing meaning loss
- over-compression
- casual questions left too raw
- longer rambly dictation left unchanged
- spoken numbers left as words
- already-good text getting over-edited

## Initial Dataset Target

Alpha-005 pre-v1 pass:

- 4,500 training examples
- 500 validation examples
- 500 held-out test examples
- train against the exact short runtime prompt used during app inference
- use a rank-16 all-layer LoRA so the GGUF adapter has enough capacity against the quantized app model

## Success Criteria

The Polished LoRA is useful if:

- short-prompt LoRA output matches or beats current long-prompt output
- known Polished regressions pass
- list structure is preserved
- filler cleanup is reliable
- spoken numbers reliably become useful numeric form
- meaning is not deleted
- profanity is not censored by default
- already-good text is not over-edited
- runtime prompt tokens can be substantially reduced
