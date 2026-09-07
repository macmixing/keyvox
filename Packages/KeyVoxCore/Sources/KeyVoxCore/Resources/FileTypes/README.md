# File-extension registry

`mime-db.json` is unchanged data from mime-db 1.54.0 at the commit recorded in
`file-types.sources.lock.json`. The lock records the source URL and SHA-256 of
each downloaded artifact. This package uses only the extension arrays; it does
not incorporate the JavaScript package or its build tooling.

The database is MIT licensed. Its documented upstream families are IANA factual
registry data (CC0), the public-domain Apache `mime.types` file and nginx mappings
(BSD-2-Clause). Keep `MIME-DB-LICENSE.txt` and `NGINX-LICENSE.txt` with the data.
The exact upstream snapshot revisions are not recorded by mime-db; the adopted
release itself is pinned and can be compared byte-for-byte with its source.

Apple continues using its existing type registry. Non-Apple platforms use this
portable registry. Neither is a complete list of every possible file extension;
an unregistered extension remains unknown. Failed resource loading is distinct
from an unknown extension. The surrounding filename-shape rules are unchanged.
