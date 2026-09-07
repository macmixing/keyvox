# Pronunciation Data Attributions

These are **modified KeyVox data files**, derived from the pinned sources in
`sources.lock.json`. Preserve this document and both complete upstream notices
when distributing the package resources or a binary containing them.

**UK Advanced Cryptics Dictionary: Copyright (c) J Ross Beresford 1993-1999.
All Rights Reserved.** Its complete permission notice is reproduced verbatim
within [SCOWL-COPYRIGHT.txt](SCOWL-COPYRIGHT.txt).

## CMU Pronouncing Dictionary

The base pronunciations derive from `cmusphinx/cmudict` revision
`74790861f652b15e4ac49015a90074ad62a27690`, under BSD-2-Clause.
[CMUDICT-LICENSE.txt](CMUDICT-LICENSE.txt) is the exact full pinned upstream
notice, including the source-code designation, funding acknowledgment, and
original disclaimer. License file URLs and hashes are in `licenses.lock.json`.

## SCOWL and its incorporated sources

Word candidates and the common-word guard list derive from `en-wl/wordlist`
revision `9829d649f007932ce672a1e8e13678a48be20d55`. Its combined output is
published under permissive MIT-like SCOWL terms. The full, unedited
[SCOWL-COPYRIGHT.txt](SCOWL-COPYRIGHT.txt) retains all incorporated notices:

- Kevin Atkinson and Benjamin Titze permissions for SCOWL/VarCon.
- Princeton WordNet permission, disclaimer, and nonendorsement requirement.
- UKACD attribution and verbatim-notice requirement.
- Modified BSD Ispell terms, including modification marking and nonendorsement.
- ENABLE, Moby, 12Dicts, Brian Kelk, and Jargon public-domain declarations and credits.

These permissions allow distribution alongside MIT-owned KeyVox code; they are
retained as their own terms, rather than relicensed to MIT. Do not use upstream
names as endorsements or restrict redistribution of the public-domain portions.

The pinned upstream notice says SCOWLv2 uses derived grammatical information
from nonfree COCA 3-gram data under its publisher's purchased authorization.
The distributed SCOWL work is expressly published with the permissive terms
above. The raw COCA corpus is not incorporated into KeyVox; its private upstream
agreement has not been independently inspected. This records the upstream
provenance assertion without claiming to have audited that private agreement.

## Artifact provenance and modifications

The pinned CMU and SCOWL downloads match their recorded SHA-256 values.
Reconstruction reproduces the original 334,984-row lexicon byte for byte using
the repository's deterministic signature encoder. Four subsequent KeyVox-owned
pronunciation additions are identified by commit in `sources.lock.json`.

The current common-word list reconstructs from the same pinned SCOWL export,
normalization, and evenly spaced sampling: 14,670 entries plus one later KeyVox
curation entry. All 14,671 current entries occur in the pinned SCOWL vocabulary.
The original generation lock became stale after these repository edits; current
hashes, original hashes, and modification commits are now recorded separately.
This audit does not alter either runtime data file.

Phonetisaurus (BSD-3-Clause) and OpenFst (Apache-2.0) are optional historical
regeneration tools. They were not used for the reproduced artifacts and are not
shipped runtime dependencies. A future regeneration using them must pin and
verify the actual toolchain and its transitive notices before adopting output.

`Tools/Pronunciation/verify_licenses.sh` checks current artifacts and complete
notice hashes. It verifies recorded identity, not an optional regeneration
toolchain's provenance or approval. Root `THIRD_PARTY_NOTICES.md` indexes other
runtime obligations.
