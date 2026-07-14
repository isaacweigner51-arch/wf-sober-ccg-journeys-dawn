---
name: ElevenLabs text-to-speech from the sandbox
description: How to generate speech via ElevenLabs when the textToSpeech/searchVoices globals aren't registered in this environment.
---

Like `generateMusic` (see `elevenlabs-music-sandbox.md`), the `textToSpeech`
and `searchVoices` globals described in the media-generation skill were not
registered in this project's sandbox — calling them threw `is not defined`.

**What worked:** call the ElevenLabs REST API directly via the
`@replit/connectors-sdk` proxy inside a `"use impure"` function:

```js
const { ReplitConnectors } = await import("@replit/connectors-sdk");
const connectors = new ReplitConnectors();
const resp = await connectors.proxy("elevenlabs", "/v1/text-to-speech/" + voiceId, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ text, model_id: "eleven_multilingual_v2" }),
});
const buf = Buffer.from(await resp.arrayBuffer()); // mp3 bytes
```

The `/v1/voices` list endpoint returned 401 (`missing_permissions:
voices_read`) even though TTS itself worked fine — the connected API key is
scoped for synthesis, not voice discovery. Worked around this by using
ElevenLabs' well-known premade voice IDs directly (e.g.
`21m00Tcm4TlvDq8ikWAM` Rachel, `ErXwobaYiN019PkySvjV` Antoni,
`pNInz6obpgDQGcFmaJgB` Adam, `EXAVITQu4vr4xnSDxMaL` Bella,
`TxGEqnHWrfWFTfGW9XjX` Josh) — verify each with a 1-word test call before
bulk-generating, since availability isn't guaranteed per account.

Output is mp3, not wav. If the project needs `.wav` (e.g. Godot
`AudioStreamPlayer` assets already stored as wav), pipe through `ffmpeg`
(available in this environment) to convert: `ffmpeg -y -i in.mp3 -ar 44100
-ac 1 out.wav`.

**How to apply:** If `textToSpeech`/`searchVoices` are undefined, or
`/v1/voices` 401s with a permissions error, don't conclude voice generation
is unavailable — use the connectors-sdk proxy against ElevenLabs' documented
REST API directly, with a known premade voice ID if voice search is blocked.
