# Runbooks

Every resolved incident gets an entry here. This is how the command center gets
smarter over time: the next occurrence of a problem should be faster because the
last one is written down.

## When to add one

After any real troubleshooting session that ended in a fix, not routine checks.
Claude should offer to write the entry once the fix is confirmed.

## Naming

    YYYY-MM-DD-short-slug.md      e.g. 2026-07-06-gluetun-tunnel-drop.md

## Template

    # <title>

    - Date:
    - Affected: <host / app / pool>
    - Severity: <annoyance | degraded | outage>

    ## Symptom
    What was observed, in the words it was first reported.

    ## Root cause
    What was actually wrong, once known.

    ## Fix
    The exact commands or steps that resolved it.

    ## Prevention / detection
    How to stop it recurring, or how to catch it sooner next time
    (a monitoring alert, a config change, a note added to an infra/ file).
