# Swift Crypto distribution record

KeyVoxModels uses the Crypto product from Swift Crypto 4.5.2 for streaming model
file SHA-256. Apple production builds use its CryptoKit forwarding implementation;
Android uses its vendored native implementation. Core has no dependency on this
package. Exact revisions, component scope, and notice hashes are recorded in
[provenance.json](provenance.json). The combined Android harness native link
measurement is in [link-audit.json](link-audit.json); its prefixed Crypto SHA-256
symbols coexist with the separate SDK TLS archives. Swift ASN.1 does not appear
in that link map.

Swift Crypto and resolved Swift ASN.1 are Apache-2.0. Preserve their LICENSE and
NOTICE files when distributing relevant material. Swift ASN.1 is referenced by
CryptoExtras, outside the Crypto product's runtime target closure. Existing
SwiftNIO-derived attribution remains in NOTICE; upstream Wycheproof test vectors
are not incorporated into KeyVox tests or the Crypto runtime target graph.

The bundled BoringSSL revision uses Apache-2.0. Its retained license is specific
to this revision and must not be confused with the separate Swift Android SDK's
TLS-library notices. Fiat-generated arithmetic carries the retained Apache-2.0
notice and author attribution. Its pinned source records cover generated code,
including the referenced Bedrock-origin P256 implementation. METADATA's old
LICENSE-MIT description differs from the actual bundled Apache declaration; both
referenced Fiat revisions provide Apache and MIT alternatives. Historical code
generation has not been independently reproduced.

XKCP implementation files carry CC0 waivers. Its Brian Gladman endian header has
BSD-like permissive conditions, including reproducing the full copyright,
conditions, and disclaimer in binary distribution documentation. The verbatim
source notices in XKCP-NOTICES.txt preserve these terms and implementer attribution.

These components permit distribution with MIT-licensed KeyVox code while retaining
their own notices and terms. Include this notice directory with distributed
artifacts that incorporate these components; an MIT license for KeyVox does not
relicense third-party material. No model, lexicon, corpus, or external test dataset
is added by this capability. Changes to resolved versions require refreshing the
record against the actual distributed sources and native dependency graph.
