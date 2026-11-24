# Shared G1 contracts — pinned source
    - `g1/` is a byte-for-byte **G1-CANDIDATE-2026-11-19** specification copy, not working backend code.
    - `g1-locked-sha256.json` locks every source artifact, both repositories must use the same pin.
    - Run `python3 scripts/check_contracts.py` before push. Only update by one reviewed cross-repository change.
    - OpenAPI 3.1 currently includes generic request DTO placeholders. Do **not** generate writable endpoint clients for untyped operations until reviewed.
    - Local working sample implements only a tiny safe subset, documented in README. No generated client, actual SQL deployment, AI provider or MCP service exists.
