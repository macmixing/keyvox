# KeyVox Casual LoRA Spec

## Purpose

Casual is a light dictation cleanup pass. It should remove obvious spoken filler while preserving the user's casual voice, grammar, slang, profanity, structure, and meaning.

Chill is an accessory to Casual. The Casual LoRA owns the cleanup behavior. Chill's existing formatter owns lowercase and punctuation styling and must remain untouched.

## Casual Should Do

- Remove clear dictation filler such as `um`, `uh`, `hm`, `ah`, and `er`.
- Preserve `like`.
- Preserve profanity.
- Preserve slang.
- Preserve informal grammar, including incorrect grammar.
- Preserve every meaningful input word and idea from beginning to end.
- Preserve paragraph breaks.
- Preserve list structure, numbering, bullets, and item order.
- Remove filler inside list items without flattening the list.
- Format numbers, dates, money, and percentages correctly when context is clear.
- Leave clean text unchanged when there is nothing meaningful to clean.
- Make only light cleanup changes.

## Casual Should Not Do

- Polish the text.
- Copyedit the text.
- Make the text sound professional.
- Rewrite sentences for style.
- Tighten or compress meaning.
- Remove `like`.
- Remove profanity.
- Remove slang.
- Fix `ain't`.
- Fix grammar like `what you be doing`.
- Fix grammar like `Sarah and me was`.
- Fix sentence structure just because it is informal.
- Merge paragraphs.
- Flatten lists into sentences.
- Drop the beginning or ending of the input.
- Add new meaning.
- Remove meaningful words.
- Change the user's voice.

## Training Priorities

1. Strong no-op coverage for already-clean casual text.
2. Heavy contrast coverage where `um`/`uh`/`hm` are removed but `like` remains.
3. Bad grammar preservation cases.
4. Profanity and slang preservation cases.
5. Paragraph preservation cases.
6. List preservation cases.
7. Realistic normalized numbers, dates, money, and percentages.

## Acceptance

The adapter is acceptable only when the Casual live suite and the separate Casual gauntlet pass with no hard-coded fallback behavior and no changes to Chill's formatter.
