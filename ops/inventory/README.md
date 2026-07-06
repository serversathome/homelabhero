# Inventory snapshots

`hh inventory --save` writes machine-readable snapshots here, one file per host
plus a combined `latest.md`. Because this folder is inside the git-backed ops
repo, committing snapshots gives you a history of what was running when, which is
useful for "what changed" investigations.

Run `hh inventory` for current truth; read these files for the last capture.
Nothing secret is ever written here.
