# UNO Club

Play solo against three computer opponents, or create a private multiplayer room for 2–4 people. Multiplayer games are authoritative on the server; solo games remain local.

## Development

Requires Bun, Elixir 1.15+ and Erlang/OTP. In separate terminals:

```sh
bun install
bun run dev
```

```sh
cd backend
mix deps.get
mix phx.server
```

Open the Vite URL. Vite proxies `/socket` to port 4000. `bun run check` and `bun run build` check and build the frontend. The backend exposes `GET /health`.

## Rules

Match color or value, or play a wild and choose a color. Draw one card; if it is playable, play only that card or pass; otherwise the turn ends. Skip, reverse, draw two and wild draw four take effect immediately, including when played as the final card. Reverse skips the other player in a two-player game. Wild draw four requires having no card of the active color; there is no challenge or stacking. Discards are recycled when the draw pile runs out, keeping the top card.

**House rule:** every human must call UNO before playing from two cards down to one, or immediately draw two penalty cards. Solo bots call UNO automatically.

## Multiplayer and deployment

Room codes, reconnect tokens, and admission keys are bearer secrets: share a code only with intended players, and keep both credentials private. Before joining, the client stores a random admission key in session storage so a lost initial reply can recover the same seat; the server returns a separate reconnect token. Neither credential is included in room views or invite links. A disconnected player retains their seat; a disconnected player's turn waits indefinitely for reconnection. The room expires approximately ten minutes after its last connection leaves. A server restart loses all rooms and games. No accounts, database, matchmaking, forfeit, or cross-instance coordination are provided. Run **exactly one instance**; scaling to multiple instances breaks room routing and state.

The included Render Docker deployment builds the Svelte app into Phoenix's static directory and runs an Elixir release. Set `SECRET_KEY_BASE` to a securely generated secret (Render generates one), `PHX_SERVER=true`, and `PHX_HOST` to the public hostname; `PORT` is supplied by the host. Production WebSocket origins are restricted to HTTPS on `uno-tt0m.onrender.com` and `PHX_HOST`. Use TLS in production. Room creation and channel actions are rate limited, and total rooms are bounded; these are basic abuse controls, not a substitute for edge protection.
