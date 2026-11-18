# UNO Club

A local, single-player card table with three computer opponents. No accounts or network assets required.

```sh
bun install
bun run dev
bun run check
bun run build
```

Match the discard by color or value, or play a wild and choose a color. Draw one card if you can't (or don't want to) play; if it's playable, play that card or keep it and pass. Otherwise your turn ends. Skip, reverse, draw two and wild draw four take effect immediately. Wild draw four is legal only when you have no card of the active color; there is no challenge or stacking.

**House rule:** call UNO before playing from two cards down to one, or immediately draw two penalty cards. Bots call UNO automatically. First player to empty their hand wins.
