# Third-Party Notices

This project is primarily licensed under MIT for source code (see `LICENSE.md`).
Third-party components, data, and fonts remain under their original licenses.

## Runtime Components

### whisper.cpp (binary XCFramework)
- Upstream: <https://github.com/ggml-org/whisper.cpp>
- License: MIT
- Note: bundled through `Packages/KeyVoxWhisper`

Copyright (c) The ggml authors

### OpenAI Whisper (code + model weights)
- Upstream: <https://github.com/openai/whisper>
- License: MIT
- Note: model artifacts are downloaded by the app at runtime

Copyright (c) 2022 OpenAI

### MIT License (applies to the two components above)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Pronunciation Data Sources

### CMU Pronouncing Dictionary (CMUdict)
- Upstream: <https://github.com/cmusphinx/cmudict>
- License family: BSD-2-Clause style notice/disclaimer
- Used for: `Resources/Pronunciation/lexicon-v1.tsv`

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

### SCOWL (Spell Checker Oriented Word Lists)
- Upstream: <https://github.com/en-wl/wordlist>
- License family: permissive SCOWL copyright notice (non-SPDX custom text)
- Used for: `Resources/Pronunciation/common-words-v1.txt` and lexicon candidate vocabulary

Copyright 2000-2025 by Kevin Atkinson

Permission to use, copy, modify, distribute and sell these word lists,
the associated scripts, the output created from the scripts, and its
documentation for any purpose is hereby granted without fee, provided
that the above copyright notice appears in all copies and that both
that copyright notice and this permission notice appear in supporting
documentation.

THE WORD LISTS, SCRIPTS, AND OUTPUT FILES ARE PROVIDED "AS IS",
WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDER
BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN
CONNECTION WITH THE WORD LISTS, SCRIPTS, OR OUTPUT FILES OR THE USE OR
OTHER DEALINGS IN THEM.

## Bundled Font

### Kanit Font
- Upstream: <https://github.com/cadsondemak/kanit>
- License: SIL Open Font License 1.1 (OFL-1.1)
- Bundled file: `Resources/Kanit-Medium.ttf`

Full OFL text is bundled in `Resources/OFL.txt`.

## Build-Time Tooling (not shipped in app runtime)

### Phonetisaurus
- Upstream: <https://github.com/AdolfVonKleist/Phonetisaurus>
- License: BSD-3-Clause
- Use: maintainer-only lexicon generation path

### OpenFst
- Upstream: <https://www.openfst.org/>
- License: Apache-2.0
- Use: transitive build-time dependency for Phonetisaurus workflows
