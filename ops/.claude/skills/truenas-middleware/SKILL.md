---
name: truenas-middleware
description: >
  Discover and use the live TrueNAS middleware method surface instead of
  guessing. Use this whenever a TrueNAS task needs a midclt method that is not
  in capabilities/truenas.md, whenever Evan asks about the TrueNAS API, the
  middleware, midclt, "what can the API do", available methods, or method
  parameters, or whenever a midclt call fails with an unknown-method or bad-
  argument error. Trigger this to look up the real methods, their exact names,
  and their parameter schemas on THIS box rather than relying on the static
  catalog. Prefer this over guessing method names for anything beyond the common
  operations already documented.
---

# TrueNAS middleware introspection

`capabilities/truenas.md` is the fast path for common work. This skill is for
everything beyond it: the middleware exposes many hundreds of methods, and their
names, parameters, and return shapes vary by TrueNAS version. Do not guess. Read
them off the actual box.

All commands run through the broker, e.g. `hh run truenas "<command>"`. TrueNAS
ships python3 (the middleware is python), so python3 is the reliable JSON parser;
jq may or may not be present, so check with `command -v jq` before relying on it.

## List the methods that actually exist

    # every method name on this box, sorted
    midclt call core.get_methods | python3 -c "import json,sys;[print(k) for k in sorted(json.load(sys.stdin))]"

    # only a namespace you care about (e.g. everything under 'pool')
    midclt call core.get_methods | python3 -c "import json,sys;[print(k) for k in sorted(json.load(sys.stdin)) if k.startswith('pool')]"

Namespaces are regular: `pool.*`, `pool.dataset.*`, `pool.snapshottask.*`,
`app.*`, `service.*`, `interface.*`, `sharing.smb.*`, `replication.*`,
`disk.*`, `system.*`, `virt.instance.*`, and so on. Filter by the prefix that
matches the task.

## Inspect a method BEFORE you call it

For any state-changing method, look up its accepts schema so you pass the right
arguments, then confirm with Evan before running it.

    # description + accepted arguments + return shape for one method
    midclt call core.get_methods | python3 -c "import json,sys,pprint;pprint.pprint(json.load(sys.stdin).get('pool.dataset.create'))"

The `accepts` field is the JSON schema for the arguments; `returns` is what
comes back. Read `accepts` to build the call correctly.

## Calling methods

Arguments are passed as JSON positional args:

    # read-only query with a filter (safe)
    midclt call pool.dataset.query '[["name","=","tank/media"]]'

    # a method that takes an object argument
    midclt call service.restart '"cifs"'

Long-running operations are jobs. Add `-j` so midclt waits for completion and
returns the result instead of just a job id:

    midclt call -j pool.scrub '{"pool": "tank", "action": "START"}'

## Read vs write

Safe to run freely (read-only): anything ending in `.query`, `.config`,
`.get_instance`, `.info`, and the `core.get_*` introspection methods.

State-changing (inspect the schema first, then confirm before running): verbs
like `.create`, `.update`, `.delete`, `.start`, `.stop`, `.restart`, `.scrub`,
`.export`, `.replace`, `.wipe`. Treat pool, dataset, disk, and replication
writes as high-risk and never run them without an explicit go-ahead, per the
house rules in CLAUDE.md.

## Fallbacks

If `core.get_methods` is unavailable on a given version, `midclt call
core.get_services` lists service namespaces, and the box also serves interactive
API docs at `https://<truenas-host>/api/docs` for a human to browse. Stay on the
SSH + midclt path; do not add API keys or network API calls.

## Credentials stay off-limits

As always, never read, print, or exfiltrate credentials, and never target the
vault. Introspection is about methods, not secrets.
