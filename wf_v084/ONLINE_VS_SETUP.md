# WF Sober CCG — Online VS Private Rooms

This build replaces pass-and-play with separate-device private rooms.

## What is included

- Host Match / Join Match
- Six-digit private room codes
- Separate phones or tablets
- Class choice and ready state
- Second Chance for both players
- Turn, board, hand-count, health, Momentum, Relapse Zone and evolution synchronization
- Disconnect notification

## Start the relay server on Ubuntu

From the extracted project folder:

```bash
python3 relay_server.py --host 0.0.0.0 --port 8765
```

For two devices on the same Wi-Fi, enter the computer's LAN address in both games, such as:

```text
ws://192.168.1.25:8765
```

Find the address with:

```bash
hostname -I
```

## Play over the internet from separate homes

The relay must have a public secure WebSocket address. A quick test option is a Cloudflare tunnel:

```bash
cloudflared tunnel --url http://localhost:8765
```

Cloudflare prints a temporary `https://...trycloudflare.com` address. Enter the same address in both games, changing `https://` to `wss://`.

Example:

```text
wss://example-random.trycloudflare.com
```

Keep the relay terminal and tunnel terminal open during the match.

## Match flow

1. Both players open **VS FRIEND — ONLINE**.
2. Both enter the same relay address.
3. The host taps **HOST MATCH** and shares the six-digit code.
4. The second player enters the code and taps **JOIN MATCH**.
5. Both choose a class and become ready automatically.
6. Both complete Second Chance.
7. The host takes the first turn; the other player receives the synchronized state.

## Important testing note

This is a private-room testing build. The relay forwards match state and is not yet an anti-cheat ranked server. It is intended for trusted friends and testers.
