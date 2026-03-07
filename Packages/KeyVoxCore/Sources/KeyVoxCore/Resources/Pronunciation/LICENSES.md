# Pronunciation Data Attributions

These package resources contain pronunciation artifacts and attribution metadata used by KeyVox's offline dictionary matcher:

- `lexicon-v1.tsv`
- `common-words-v1.txt`
- `LICENSES.md`
- `sources.lock.json`

The build pipeline is maintainer-only and runs via:

- `Tools/Pronunciation/build_lexicon.sh`
- `Tools/Pronunciation/train_g2p.sh`
- `Tools/Pronunciation/verify_licenses.sh`

Runtime transcription remains fully offline. The app does not download pronunciation data.

## Upstream Sources

### 1) CMU Pronouncing Dictionary
- Project: `cmusphinx/cmudict`
- License: BSD-2-Clause
- Use: base pronunciation lexicon for `lexicon-v1.tsv`
- Snapshot pin + checksum: see `sources.lock.json`

License notice (from upstream `LICENSE`):

```
Copyright (C) 1993-2015 Carnegie Mellon University. All rights reserved.

Portions Copyright 2007-2009 Alan W Black, Kevin Lenzo, and
Vishnu Pillai.

All modifications made in this distribution are Copyright 2023
Carnegie Mellon University.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in
   the documentation and/or other materials provided with the
   distribution.

THIS SOFTWARE IS PROVIDED BY CARNEGIE MELLON UNIVERSITY "AS IS" AND
ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CARNEGIE MELLON UNIVERSITY
NOR OTHER CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### 2) SCOWL (Spell Checker Oriented Word Lists)
- Project: `en-wl/wordlist` (SCOWL data/tooling)
- License: MIT-like SCOWL copyright terms
- Use: common-word guard list + OOV vocabulary candidates
- Snapshot pin + checksum: see `sources.lock.json`

Permission notice (from upstream `Copyright`):

```
Copyright 2000-2025 by Kevin Atkinson

Permission to use, copy, modify, distribute and sell these word
lists, the associated scripts, the output created from the scripts,
and its documentation for any purpose is hereby granted without fee,
provided that the above copyright notice appears in all copies and
that both that copyright notice and this permission notice appear in
supporting documentation.

THE WORD LISTS, SCRIPTS, AND OUTPUT FILES ARE PROVIDED "AS IS",
WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDER
BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN
CONNECTION WITH THE WORD LISTS, SCRIPTS, OR OUTPUT FILES OR THE USE OR
OTHER DEALINGS IN THEM.
```

Upstream SCOWL copyright/source notice file:
- `https://github.com/en-wl/wordlist/blob/9829d649f007932ce672a1e8e13678a48be20d55/Copyright`

### 3) Phonetisaurus
- Project: `AdolfVonKleist/Phonetisaurus`
- License: BSD-3-Clause
- Use: build-time grapheme-to-phoneme generation for OOV words
- Not shipped as runtime dependency in KeyVox app binary

### 4) OpenFst
- Project: OpenFst
- License: Apache-2.0
- Use: build-time dependency used by Phonetisaurus
- Not shipped as runtime dependency in KeyVox app binary

## Compliance Notes

1. `sources.lock.json` is the source-of-truth for pinned source revisions, output paths, and checksums.
2. Regeneration must pass `Tools/Pronunciation/verify_licenses.sh` before commit.
3. If source snapshots are updated, this file and the package resource metadata must be updated in the same change.
4. App-level notices for non-package dependencies remain in `THIRD_PARTY_NOTICES.md`; package-owned pronunciation notices live here.
