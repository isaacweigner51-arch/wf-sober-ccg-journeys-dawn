---
name: Godot 4 TextureRect expand_mode ordering bug
description: Setting expand_mode after texture assignment resets node size to native texture dimensions — causes zoom/crop bugs in clipped containers.
---

## The rule
Always set `expand_mode` and `stretch_mode` on a TextureRect **before** assigning `.texture`.

## Why
Godot 4 has a layout bug: if you assign `.texture` first, then set `.expand_mode`, the engine resets the node's size to the texture's native pixel dimensions. For 1024×1024 leader PNGs inside a 200×200 or 392×352 clipped parent, the TextureRect becomes 1024×1024, and the parent clips it — showing only the center slice of the canvas. Result: extreme zoom on opaque art, or a solid class-color square when the layers are transparent (the aura_bg ColorRect shows through all the "off-screen" transparent pixels).

## How to apply
Whenever constructing a TextureRect that will receive a texture at build time:

```gdscript
# CORRECT — expand_mode before texture
var t := TextureRect.new()
t.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
t.texture = load(path)   # assigned AFTER
t.size = desired_size
```

```gdscript
# WRONG — triggers the size-reset bug
var t := TextureRect.new()
t.texture = load(path)   # assigned FIRST
t.size = desired_size
t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # resets size to 1024×1024
```

This applies to every TextureRect in the project, especially `_make_layer()` in `leader_view.gd` and any art node in card/leader panels.
