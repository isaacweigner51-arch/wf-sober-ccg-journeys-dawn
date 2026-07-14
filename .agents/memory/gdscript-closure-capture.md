---
name: GDScript lambda closures capture by value, not reference
description: Verified behavior of `func():` lambdas in Godot 4 GDScript relevant to any code that creates a Button/Callable and needs the callback to reference that same object.
---

GDScript `func():` lambdas snapshot outer local variables **by value at creation time**. A pattern like:

```gdscript
var b: Button
b = button(text, pos, size, func():
    if is_instance_valid(b): b.disabled = true  # b captured as null here, forever
)
```

silently captures `b` as its value at the moment the lambda literal is evaluated (still unset), not a live reference — so `is_instance_valid(b)` is always false inside the closure, even after `b` is assigned.

**Why:** confirmed empirically with a minimal `--headless --script` repro in this project (wf-sober-ccg): printing a captured local after reassignment shows the pre-assignment value.

**How to apply:** when a closure needs to see a value set *after* the closure is created (e.g. a button referencing itself, or one callback needing to enable a button created later), box the value in a `Dictionary` or `Array` declared before any of the closures and mutate that container instead of a bare local — dict/array contents are reference-shared even though the variable binding itself is still captured by value. This project's `menu.gd` already uses a `controls := {"confirm": null, ...}` dict for exactly this reason in a few of the Academy lesson builder functions; follow that pattern for any new self-referencing UI callback instead of a plain local var (which will look correct in code review but soft-lock the UI at runtime).
