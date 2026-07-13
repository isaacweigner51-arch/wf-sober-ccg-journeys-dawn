# v0.7.8 — Walking Free Evolution Freeze Fix

- Signature-card voice playback now has a hard timeout and can no longer lock the battle coroutine.
- Signature evolution finds the live battlefield card reliably even if its Dictionary was copied or normalized.
- The evolved gameplay state is applied before the visual animation, preventing audio or animation interruptions from cancelling the effect.
- Walking Free now reliably evolves for free, gains its evolved stats, buffs Purpose followers remaining in the deck by +1/+1, recovers 2 PP, draws 2 cards, and enables its sequencing leader effect.
- The same reliability fix applies to the other signature cards that use the shared free-evolution path.
