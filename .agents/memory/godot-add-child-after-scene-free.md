---
name: add_child crashes surviving scene/node teardown
description: Why "Cannot call method 'add_child' on a previously freed instance" can persist even after guarding the obvious node, and the general fix pattern.
---

Guarding a single suspect node (e.g. a results/finish layer) with `is_instance_valid()` after
each `await` is not sufficient if OTHER long-lived coroutines also do `add_child` on `self`
or another shared node — e.g. floating damage-number popups, speech bubbles, or any effect
with its own multi-second timer. If the player backs out to the main menu (which frees the
whole scene) or restarts a match while one of those is still mid-flight, the *next*
`add_child` call after its `await` crashes with the same generic freed-instance error, even
though the originally-reported crash site was already fixed.

**Why:** each `await`-driven coroutine resumes independently; fixing the crash's most obvious
call site doesn't stop siblings coroutines from hitting the same failure mode later.

**How to apply:** add one small helper (`safe_add_child(parent, child)`) that checks
`is_instance_valid(parent)` before adding and queue_frees the orphaned child otherwise —
mirrors this project's existing `safe_set_text`/`safe_set_disabled` pattern — and apply it at
every `add_child` call that happens after an `await`, not just the one node the bug report
pointed at. Re-verify by asking what OTHER effects could still be running (barks, popups,
tweens) whenever a "crash after the match/scene ends" report doesn't go away after the first
fix.
