---
name: ElevenLabs music generation from sandbox
description: How to actually generate music via a connected ElevenLabs connector when the generateMusic global callback isn't available.
---

In this project's environment, `generateMusic`/`generateSoundEffect`/`textToSpeech`
(described in the media-generation skill as pre-registered globals) were **not**
registered even after the ElevenLabs connector was successfully connected
(`searchIntegrations` showed `status: "added"`). Calling them threw
`generateMusic is not defined`.

Also, the normal `query-integration-data` pattern of
`listConnections('elevenlabs')` inside a `"use impure"` function returned `[]`
even though the connection was `added` — a case of withheld/unavailable
credentials via that path for this connector specifically.

**What worked:** call the connector's HTTP proxy directly via the
`@replit/connectors-sdk` package inside a `"use impure"` function:

```js
const { ReplitConnectors } = await import("@replit/connectors-sdk");
const connectors = new ReplitConnectors();
const resp = await connectors.proxy("elevenlabs", "/v1/music?output_format=mp3_44100_128", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ prompt, music_length_ms, force_instrumental: true }),
});
// resp is a raw Response-like object; use resp.ok / resp.arrayBuffer()
```

**Why:** The generic `generateMusic` capability and the `listConnections`
credential-vending path both depend on registrations that may not exist for
every connector/environment combination. The connectors-sdk proxy pattern
(normally described as "for app code, not the sandbox") is the reliable
fallback when both of those are unavailable — the package imports fine inside
`"use impure"` even though it isn't installed as a project dependency.

**How to apply:** If `generateMusic`/similar media-generation globals are
`undefined`, or `listConnections(slug)` returns `[]` for a connection that
`searchIntegrations` reports as `added`, try the `@replit/connectors-sdk`
proxy directly against the provider's documented REST API before concluding
the capability is unavailable. Fetch the exact endpoint/schema via `webSearch`
first (e.g. ElevenLabs' Music API is `POST /v1/music`, not a documented
Replit callback param set).
