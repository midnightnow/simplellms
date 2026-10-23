#!/usr/bin/env python3
"""Validate a JSON document against a JSON Schema.

Usage: validate_epic.py <schema.json> <document.json>

Prefers the `jsonschema` package when available. Falls back to a minimal
validator that supports the keywords used by epic.schema.json: type,
required, properties, items, $ref (#/$defs/...), enum, pattern, minimum.
Exit 0 when valid; prints one error per line to stderr and exits 1 otherwise.
"""
import json
import re
import sys

TYPES = {
    "object": dict,
    "array": list,
    "string": str,
    "integer": int,
    "number": (int, float),
    "boolean": bool,
    "null": type(None),
}


def _type_ok(value, t):
    if t == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if t == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if t == "boolean":
        return isinstance(value, bool)
    return isinstance(value, TYPES[t])


def _resolve(ref, root):
    if not ref.startswith("#/"):
        raise ValueError(f"unsupported $ref: {ref}")
    node = root
    for part in ref[2:].split("/"):
        node = node[part.replace("~1", "/").replace("~0", "~")]
    return node


def validate(value, schema, root, path, errors):
    if "$ref" in schema:
        validate(value, _resolve(schema["$ref"], root), root, path, errors)
        return
    t = schema.get("type")
    if t is not None:
        types = t if isinstance(t, list) else [t]
        if not any(_type_ok(value, x) for x in types):
            errors.append(f"{path}: expected type {t}, got {type(value).__name__}")
            return
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: {value!r} not in enum {schema['enum']}")
    if "pattern" in schema and isinstance(value, str):
        if not re.search(schema["pattern"], value):
            errors.append(f"{path}: {value!r} does not match pattern {schema['pattern']}")
    if "minimum" in schema and isinstance(value, (int, float)) and not isinstance(value, bool):
        if value < schema["minimum"]:
            errors.append(f"{path}: {value} < minimum {schema['minimum']}")
    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path}: missing required property '{key}'")
        for key, sub in schema.get("properties", {}).items():
            if key in value:
                validate(value[key], sub, root, f"{path}.{key}", errors)
    if isinstance(value, list) and "items" in schema:
        for i, item in enumerate(value):
            validate(item, schema["items"], root, f"{path}[{i}]", errors)


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    with open(argv[1]) as fh:
        schema = json.load(fh)
    try:
        with open(argv[2]) as fh:
            doc = json.load(fh)
    except json.JSONDecodeError as exc:
        print(f"$: document is not valid JSON: {exc}", file=sys.stderr)
        return 1

    try:
        import jsonschema  # type: ignore

        errs = sorted(jsonschema.Draft202012Validator(schema).iter_errors(doc), key=lambda e: list(e.path))
        errors = [f"$.{'.'.join(str(p) for p in e.path)}: {e.message}" for e in errs]
    except ImportError:
        errors = []
        validate(doc, schema, schema, "$", errors)

    for e in errors:
        print(e, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
