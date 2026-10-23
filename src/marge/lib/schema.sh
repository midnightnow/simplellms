#!/usr/bin/env bash
# Schema validation for epic.json against schemas/epic.schema.json.
#
#   schema_validate_epic <epic.json>   → exit 0 if valid; errors on stderr otherwise
#
# Uses python3 `jsonschema` when installed, otherwise a small built-in
# validator (lib/validate_epic.py) that covers the subset of JSON Schema
# our epic schema actually uses (type, required, properties, items, $ref,
# enum, pattern, minimum).

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

schema_validate_epic() {
    local file="$1"
    [[ -f "$file" ]] || { err "schema: no such file: $file"; return 1; }
    python3 -I "$MARGE_LIB_DIR/validate_epic.py" "$MARGE_SRC_DIR/schemas/epic.schema.json" "$file"
}
