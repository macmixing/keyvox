# WordNet lexical indexes

This directory contains the four unchanged lexical index files consumed by the
portable KeyVox analyzer from the official WordNet 3.0 distribution. The data
is English-only and supplies lexical part-of-speech membership; it does not
replace KeyVox's pronunciation lexicon or user dictionary.

`sources.lock.json` pins the official archive and every distributed file. The
WordNet license permits commercial use, copying, modification, and distribution
without a fee or royalty when its copyright notice and disclaimer are retained
on all copies. Princeton's name may not be used in advertising or publicity.

The full WordNet data files, examples, glosses, and binaries are not distributed.
Only `index.noun`, `index.verb`, `index.adj`, and `index.adv` are included because
those are the only assets read by KeyVox.
