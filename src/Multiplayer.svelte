<script lang="ts">
  import { onDestroy } from "svelte";
  import { Socket, type Channel } from "phoenix";
  import CardView from "./lib/Card.svelte";
  import { COLORS, type Color, type Value } from "./lib/game";

  type Card = { id: string; color: Color | "wild"; value: Value };
  type Player = { id: string; name: string; count: number; connected: boolean };
  type RoomView = {
    code: string;
    phase: "lobby" | "playing" | "finished";
    selfId: string;
    hostId: string;
    players: Player[];
    hand: Card[];
    topCard: Card | null;
    currentPlayerId: string | null;
    currentColor: Color;
    direction: 1 | -1;
    drawnCardId: string | null;
    unoArmed: boolean;
    winnerId: string | null;
    playableIds: string[];
    log: string[];
    revision: number;
  };
  type Seat = {
    code: string;
    name: string;
    token?: string;
    admissionKey?: string;
  };
  const storageKey = "uno-room-seat";
  function readSeat(): Seat | null {
    try {
      const value = JSON.parse(sessionStorage.getItem(storageKey) || "null");
      return value &&
        typeof value.code === "string" &&
        typeof value.name === "string" &&
        (typeof value.token === "string" ||
          (typeof value.admissionKey === "string" &&
            /^[0-9a-f]{64}$/.test(value.admissionKey)))
        ? value
        : null;
    } catch {
      return null;
    }
  }
  const initialSeat = readSeat();
  let saved = $state<Seat | null>(initialSeat);
  let name = $state(initialSeat?.name ?? "");
  let code = $state(
    (
      new URLSearchParams(location.search).get("room") ||
      initialSeat?.code ||
      ""
    ).toUpperCase(),
  );
  let view = $state<RoomView | null>(null);
  let connection = $state<"idle" | "connecting" | "connected" | "reconnecting">(
    "idle",
  );
  let error = $state("");
  let notice = $state("");
  let pending = $state(false);
  let invalidSeat = $state(false);
  let colorDialog: HTMLDialogElement;
  let selected = $state<Card | null>(null);
  let socket: Socket | null = null;
  let room: Channel | null = null;
  let generation = 0;
  let currentSeat: Seat | null = null;
  let selfTurn = $derived(
    !!view &&
      view.phase === "playing" &&
      view.currentPlayerId === view.selfId &&
      connection === "connected" &&
      !pending,
  );
  let host = $derived(!!view && view.hostId === view.selfId);
  let allConnected = $derived(!!view && view.players.every((p) => p.connected));
  let currentName = $derived(
    view?.players.find((p) => p.id === view?.currentPlayerId)?.name ?? "Player",
  );
  let winnerName = $derived(
    view?.players.find((p) => p.id === view?.winnerId)?.name ?? "Player",
  );

  function cleanup() {
    generation++;
    room = null;
    socket?.disconnect();
    socket = null;
    pending = false;
  }
  onDestroy(cleanup);
  function store(seat: Seat): boolean {
    saved = seat;
    try {
      sessionStorage.setItem(storageKey, JSON.stringify(seat));
      return true;
    } catch {
      error =
        "Could not save your seat in this tab. Enable session storage before joining.";
      return false;
    }
  }
  function newSeat(code: string, name: string): Seat {
    const bytes = crypto.getRandomValues(new Uint8Array(32));
    return {
      code,
      name,
      admissionKey: Array.from(bytes, (b) =>
        b.toString(16).padStart(2, "0"),
      ).join(""),
    };
  }
  function clearSeat() {
    cleanup();
    try {
      sessionStorage.removeItem(storageKey);
    } catch {
      /* storage unavailable */
    }
    saved = null;
    currentSeat = null;
    view = null;
    connection = "idle";
    invalidSeat = false;
    error =
      "Saved seat cleared. You can join fresh only while the room is in the lobby.";
  }
  function setupSocket(): Socket {
    const s = new Socket("/socket", { timeout: 8000 });
    const id = generation;
    s.onClose(() => {
      if (id !== generation) return;
      connection = view ? "reconnecting" : "connecting";
      pending = false;
      error = "Connection lost. Reconnecting; actions are not retried.";
    });
    s.onError(() => {
      if (id !== generation) return;
      connection = view ? "reconnecting" : "connecting";
      pending = false;
      error =
        "Unable to reach the game server. Check that it is running; retrying…";
    });
    socket = s;
    s.connect();
    return s;
  }
  function acceptView(next: RoomView) {
    if (!view || next.revision >= view.revision) view = next;
  }
  function joinRoom(s: Socket, seat: Seat) {
    const id = generation;
    const params: { name: string; token?: string; admissionKey?: string } = {
      name: seat.name,
      ...(seat.token ? { token: seat.token } : {}),
      ...(seat.admissionKey ? { admissionKey: seat.admissionKey } : {}),
    };
    const ch = s.channel(`room:${seat.code}`, params);
    room = ch;
    ch.on("state", (next: RoomView) => {
      if (id === generation) acceptView(next);
    });
    ch.on("room_closed", (response: { message?: string }) => {
      if (id !== generation) return;
      cleanup();
      currentSeat = null;
      view = null;
      connection = "idle";
      error = response?.message || "This room is no longer available.";
    });
    ch.onError(() => {
      if (id !== generation) return;
      connection = "reconnecting";
      pending = false;
      error = "Room connection lost. Reconnecting; actions are not retried.";
    });
    ch.onClose(() => {
      if (id !== generation) return;
      connection = "reconnecting";
      pending = false;
      error = "Room connection closed. Rejoin to refresh your seat.";
    });
    ch.join()
      .receive(
        "ok",
        ({ token, view: next }: { token: string; view: RoomView }) => {
          if (id !== generation) return;
          params.token = token;
          currentSeat = { ...seat, token };
          store(currentSeat);
          acceptView(next);
          connection = "connected";
          pending = false;
          invalidSeat = false;
          if (!error.startsWith("Could not save")) error = "";
          const url = new URL(location.href);
          url.searchParams.set("room", seat.code);
          history.replaceState(null, "", url);
        },
      )
      .receive("error", (response: { message?: string }) => {
        if (id !== generation) return;
        error =
          response?.message ||
          "Could not join this room. Check the code or try again.";
        invalidSeat = !!seat.token;
        connection = "idle";
        cleanup();
      })
      .receive("timeout", () => {
        if (id !== generation) return;
        error =
          "The game server did not respond. Check that the backend is running and try again.";
        connection = "idle";
        cleanup();
      });
  }
  function join(useSaved = false) {
    const selectedSeat = useSaved ? saved : null;
    const roomCode = (selectedSeat?.code || code).trim().toUpperCase();
    const playerName = (selectedSeat?.name || name).trim();
    if (!playerName || !/^[A-Z0-9]{6}$/.test(roomCode)) {
      error = "Enter your name and a six-character room code.";
      return;
    }
    cleanup();
    view = null;
    error = "";
    invalidSeat = false;
    connection = "connecting";
    name = playerName;
    code = roomCode;
    const seat = selectedSeat || newSeat(roomCode, playerName);
    if (!store(seat)) {
      connection = "idle";
      return;
    }
    const s = setupSocket();
    joinRoom(s, seat);
  }
  function create() {
    const playerName = name.trim();
    if (!playerName) {
      error = "Enter your name first.";
      return;
    }
    cleanup();
    view = null;
    error = "";
    invalidSeat = false;
    connection = "connecting";
    const id = generation;
    const s = setupSocket();
    const lobby = s.channel("lobby", {});
    lobby
      .join()
      .receive("ok", () => {
        if (id !== generation) return;
        lobby
          .push("create", {}, 8000)
          .receive("ok", (response: { code: string }) => {
            if (id !== generation) return;
            code = response.code;
            lobby.leave();
            const seat = newSeat(response.code, playerName);
            if (!store(seat)) {
              connection = "idle";
              cleanup();
              return;
            }
            joinRoom(s, seat);
          })
          .receive("error", (response: { message?: string }) => {
            if (id !== generation) return;
            error = response?.message || "Could not create a room.";
            connection = "idle";
            cleanup();
          })
          .receive("timeout", () => {
            if (id !== generation) return;
            error = "Room creation timed out. Please try again.";
            connection = "idle";
            cleanup();
          });
      })
      .receive("error", (response: { message?: string }) => {
        if (id !== generation) return;
        error = response?.message || "Could not connect to the lobby.";
        connection = "idle";
        cleanup();
      })
      .receive("timeout", () => {
        if (id !== generation) return;
        error =
          "The game server did not respond. Check that the backend is running and try again.";
        connection = "idle";
        cleanup();
      });
  }
  function refreshRoom(message: string) {
    const seat = currentSeat;
    if (!seat) return;
    cleanup();
    connection = "reconnecting";
    error = message;
    notice = message;
    const s = setupSocket();
    joinRoom(s, seat);
  }
  function action(
    type: "start" | "play" | "draw" | "pass" | "uno",
    cardId?: string,
    color?: Color,
  ) {
    if (
      !view ||
      !room ||
      !socket?.isConnected() ||
      connection !== "connected" ||
      pending ||
      room.state !== "joined"
    )
      return;
    pending = true;
    const id = generation;
    room
      .push(
        "action",
        {
          type,
          ...(cardId ? { cardId } : {}),
          ...(color ? { color } : {}),
          revision: view.revision,
          commandId: crypto.randomUUID(),
        },
        8000,
      )
      .receive("ok", (response: { view: RoomView }) => {
        if (id !== generation) return;
        acceptView(response.view);
        pending = false;
        error = "";
      })
      .receive("error", (response: { message?: string }) => {
        if (id !== generation) return;
        refreshRoom(
          response?.message || "Action rejected. Refreshing the room.",
        );
      })
      .receive("timeout", () => {
        if (id !== generation) return;
        refreshRoom(
          "Action timed out. Refreshing the room; it will not be retried.",
        );
      });
  }
  function selectCard(card: Card) {
    if (!selfTurn || !view?.playableIds.includes(card.id)) return;
    if (card.color === "wild") {
      selected = card;
      colorDialog.showModal();
    } else action("play", card.id);
  }
  function chooseColor(color: Color) {
    const card = selected;
    selected = null;
    colorDialog.close();
    if (card && selfTurn && view?.playableIds.includes(card.id))
      action("play", card.id, color);
  }
  async function copy(value: string) {
    try {
      await navigator.clipboard.writeText(value);
      notice = "Copied to clipboard.";
    } catch {
      notice = `Could not copy automatically. Copy this: ${value}`;
    }
  }
</script>

<svelte:head><meta name="theme-color" content="#f7f5ef" /></svelte:head>
<div class="site-shell multiplayer">
  <header class="site-header">
    <a class="brand" href="/" aria-label="UNO Club home">
      <span class="brand-mark"><i></i><b>u</b></span><span>
        uno<span class="brand-light"> club</span><small>
          THE GOOD TIME CARD CLUB
        </small>
      </span>
    </a><span class="friends-pill">✳ PLAY WITH FRIENDS</span>
  </header>
  <main>
    <section class="intro">
      <div>
        <p class="eyebrow"><span>✳</span> GOOD CARDS. GREAT COMPANY.</p>
        <h1>Your table is ready<span>.</span></h1>
        <p class="subtitle">A private table for two to four friends.</p>
      </div>
    </section>
    {#if error}<p class="message error" role="alert">{error}</p>{/if}
    {#if notice}<p class="message" role="status">{notice}</p>{/if}
    {#if connection !== "connected" && connection !== "idle"}<p
        class="message"
        role="status"
      >
        {connection === "connecting"
          ? "Connecting to the game server…"
          : "Reconnecting to your room…"}
      </p>{/if}
    {#if view && connection !== "connected"}<div class="room-actions">
        {#if saved}<button class="outline-button" onclick={() => join(true)}>
            Retry room connection
          </button>{/if}{#if invalidSeat && saved}<button
            class="outline-button"
            onclick={clearSeat}
          >
            Clear saved seat and join fresh
          </button>{/if}
      </div>{/if}
    {#if !view}
      <section class="room-panel" aria-label="Join or create a room">
        <p class="section-kicker">YOUR PRIVATE TABLE</p>
        <h2>Bring your friends<span>.</span></h2>
        <label>
          Your name <input
            bind:value={name}
            maxlength="40"
            autocomplete="nickname"
          />
        </label>
        <label>
          Room code <input
            bind:value={code}
            maxlength="6"
            autocomplete="off"
            placeholder="ABCDEF"
          />
        </label>
        <div class="room-actions">
          <button
            class="dialog-primary"
            disabled={connection !== "idle"}
            onclick={() => join(false)}
          >
            Join room
          </button><button
            class="outline-button"
            disabled={connection !== "idle"}
            onclick={create}
          >
            Create room
          </button>{#if saved}<button
              class="outline-button"
              disabled={connection !== "idle"}
              onclick={() => join(true)}
            >
              Resume room {saved.code}
            </button>{/if}
        </div>
        {#if invalidSeat && saved}<button
            class="text-button clear-seat"
            onclick={clearSeat}
          >
            Clear saved seat and join fresh
          </button>{/if}
        <p>
          Share the room code or link with friends. Seats are held for
          disconnected players; their turns wait until they reconnect.
        </p>
      </section>
    {:else}
      <div class="room-bar">
        <div>
          <span class="section-kicker">ROOM CODE</span><strong>
            {view.code}
          </strong>
        </div>
        <button class="outline-button" onclick={() => copy(view!.code)}>
          Copy code
        </button><button
          class="outline-button"
          onclick={() => {
            const url = new URL(location.origin + location.pathname);
            url.searchParams.set("room", view!.code);
            copy(url.toString());
          }}
        >
          Copy invite link
        </button><span>
          {connection === "connected" ? "● Connected" : "○ Reconnecting"}
        </span>
      </div>
      <p class="seat-note">
        Disconnected players keep their seats. Their turns wait until they
        reconnect.
      </p>
      {#if view.phase === "lobby"}
        <section class="room-panel">
          <p class="section-kicker">THE LOBBY</p>
          <h2>Gather around<span>.</span></h2>
          <p>
            {view.players.length} / 4 players · At least two players are needed to
            start.
          </p>
          <ul class="lobby-players">
            {#each view.players as player (player.id)}<li>
                <strong>
                  {player.name}{player.id === view.selfId ? " (you)" : ""}
                </strong><span>
                  {player.id === view.hostId ? "Host · " : ""}{player.connected
                    ? "Connected"
                    : "Disconnected"}
                </span>
              </li>{/each}
          </ul>
          {#if host}<button
              class="dialog-primary"
              disabled={view.players.length < 2 ||
                !allConnected ||
                connection !== "connected" ||
                pending}
              onclick={() => action("start")}
            >
              Start game
            </button>{#if !allConnected}<p>
                Waiting for all seated players to reconnect.
              </p>{/if}{:else}<p>
              Waiting for the host to start the game.
            </p>{/if}
        </section>
      {:else}
        <div class="game-layout">
          <section class="game-main" aria-label="UNO game table">
            <div class="table multi-table">
              <div class="table-border"></div>
              <div class="table-rings"></div>
              <div class="table-top">
                <span>THE UNO CLUB ✳</span><span>EST. FOR GOOD TIMES</span>
              </div>
              <div class="opponents">
                {#each view.players.filter((p) => p.id !== view!.selfId) as player, i (player.id)}<div
                    class="opponent"
                    class:active={view.currentPlayerId === player.id &&
                      view.phase === "playing"}
                  >
                    <div class="avatar avatar-{i + 1}" aria-hidden="true">
                      ☺
                    </div>
                    <div class="opponent-info">
                      <strong>{player.name}</strong><span>
                        {player.count} cards · {player.connected
                          ? "Connected"
                          : "Disconnected"}
                      </span>
                    </div>
                  </div>{/each}
              </div>
              <div class="table-center">
                <div class="pile-wrap">
                  <button
                    class="deck"
                    aria-label="Draw a card"
                    disabled={!selfTurn || view.drawnCardId !== null}
                    onclick={() => action("draw")}
                  >
                    <span>UNO</span>
                  </button><span class="pile-label">DRAW PILE</span>
                </div>
                <div class="center-plus">✳</div>
                <div class="pile-wrap">
                  {#if view.topCard}<CardView
                      card={view.topCard}
                      display
                    />{/if}<span class="pile-label">DISCARD PILE</span>
                </div>
              </div>
              <div class="table-bottom">
                <div class="color-badge">
                  <span class="color-dot {view.currentColor}"></span> ACTIVE
                  COLOR <strong>{view.currentColor}</strong>
                </div>
                <div class="direction">
                  {view.direction === 1 ? "↻" : "↺"}
                  <span>
                    {view.direction === 1 ? "CLOCKWISE" : "COUNTERCLOCKWISE"}
                  </span>
                </div>
              </div>
              <div class="your-seat">
                <span class="your-avatar">☺</span><span>
                  <strong>You</strong><small>
                    {selfTurn ? "YOUR TURN" : "AT THE TABLE"}
                  </small>
                </span><i class:lit={selfTurn}></i>
              </div>
            </div>
            <div class="hand-section">
              <div class="hand-heading">
                <div>
                  <span class="section-kicker">YOUR HAND</span><span
                    class="hand-count"
                  >
                    {view.hand.length} cards
                  </span>
                </div>
                <div class="turn-status" aria-live="polite">
                  <span></span>{view.phase === "finished"
                    ? `${winnerName} wins!`
                    : selfTurn
                      ? "Your move"
                      : `${currentName}'s turn`}
                </div>
              </div>
              <div class="hand-content">
                <div class="hand-scroll" aria-label="Your cards">
                  {#each view.hand as card (card.id)}<CardView
                      {card}
                      playable={selfTurn && view.playableIds.includes(card.id)}
                      disabled={!selfTurn ||
                        !view.playableIds.includes(card.id)}
                      onclick={() => selectCard(card)}
                    />{/each}
                </div>
                <button
                  class="uno-button"
                  class:armed={view.unoArmed}
                  disabled={!selfTurn ||
                    view.hand.length !== 2 ||
                    view.unoArmed}
                  onclick={() => action("uno")}
                >
                  {view.unoArmed ? "UNO ✓" : "UNO!"}
                </button>
              </div>
              <div class="hand-footer">
                <p>
                  {view.unoArmed
                    ? "UNO called! Now play your card."
                    : selfTurn && view.hand.length === 2
                      ? "Call UNO before playing down to one card!"
                      : selfTurn && view.drawnCardId !== null
                        ? "Play your drawn card or pass."
                        : "Match the color or symbol, or play a wild."}
                </p>
                <button
                  class="draw-button"
                  disabled={!selfTurn}
                  onclick={() =>
                    action(view!.drawnCardId !== null ? "pass" : "draw")}
                >
                  {selfTurn && view.drawnCardId !== null
                    ? "Keep card / Pass"
                    : "Draw a card"} <span>↗</span>
                </button>
              </div>
              {#if view.phase === "finished"}<div class="room-panel">
                  <h2>{winnerName} wins<span>!</span></h2>
                  {#if host}<button
                      class="dialog-primary"
                      disabled={!allConnected ||
                        connection !== "connected" ||
                        pending}
                      onclick={() => action("start")}
                    >
                      Play again
                    </button>{#if !allConnected}<p>
                        Waiting for all seated players to reconnect.
                      </p>{/if}{:else}<p>
                      Waiting for the host to start a rematch.
                    </p>{/if}
                </div>{/if}
            </div>
          </section>
          <aside class="sidebar">
            <div class="sidebar-header">
              <div>
                <span class="section-kicker">THE LATEST</span>
                <h2>Table talk<span>.</span></h2>
              </div>
              <span class="chat-icon">✳</span>
            </div>
            <p class="sidebar-subtitle">A little play-by-play, just for you.</p>
            <div class="activity-list" aria-live="polite">
              {#each view.log.slice(0, 5) as entry, i}<div class="activity">
                  <span class="activity-dot" class:latest={i === 0}></span>
                  <p>{entry}</p>
                </div>{/each}
            </div>
            <div class="tip">
              <span>✳ &nbsp; A LITTLE REMINDER</span>
              <p>
                Down to two cards? Call <strong>UNO!</strong> before you play your
                next one.
              </p>
            </div>
          </aside>
        </div>
      {/if}
    {/if}
    <footer>
      <span>MADE FOR PLAYING TOGETHER <b>✳</b></span><span>
        NO BAD HANDS, JUST GOOD STORIES.
      </span>
    </footer>
  </main>
</div>
<dialog
  bind:this={colorDialog}
  onclose={() => (selected = null)}
  aria-labelledby="multi-color-title"
>
  <div class="dialog-content">
    <p class="eyebrow">MAKE IT YOURS</p>
    <h2 id="multi-color-title">Pick a color<span>.</span></h2>
    <p>Choose the color for the next player to match.</p>
    <div class="color-choices">
      {#each COLORS as color}<button
          class="color-choice"
          onclick={() => chooseColor(color)}
        >
          <span class="color-dot {color}"></span>{color}
        </button>{/each}
    </div>
    <button
      class="text-button cancel-choice"
      onclick={() => colorDialog.close()}
    >
      Cancel
    </button>
  </div>
</dialog>

<style>
  .room-panel {
    background: #f0f0e7;
    border: 1px solid #e0e6d9;
    border-radius: 18px;
    padding: 26px;
    max-width: 650px;
  }
  .room-panel h2 {
    font-size: 28px;
    margin: 10px 0;
    letter-spacing: -1px;
  }
  .room-panel p,
  .seat-note {
    color: #617568;
    font-size: 12px;
    line-height: 1.6;
  }
  .room-panel label {
    display: block;
    margin: 16px 0;
    color: #344238;
    font-weight: 800;
    font-size: 12px;
  }
  .room-panel input {
    display: block;
    width: 100%;
    margin-top: 6px;
    padding: 12px;
    border: 1px solid #b8cbb9;
    border-radius: 7px;
    background: white;
    color: #202720;
    font: inherit;
  }
  .room-actions,
  .room-bar {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    align-items: center;
  }
  .room-bar {
    background: #f0f0e7;
    padding: 15px;
    border-radius: 12px;
  }
  .room-bar strong {
    display: block;
    letter-spacing: 2px;
    margin-top: 4px;
  }
  .room-bar > span {
    font-size: 12px;
    color: #426c52;
    margin-left: auto;
  }
  .message {
    padding: 12px 15px;
    border-radius: 8px;
    background: #e0e9d9;
    font-size: 13px;
    overflow-wrap: anywhere;
  }
  .message.error {
    background: #fae2d8;
    color: #853c2d;
  }
  .clear-seat {
    margin-top: 20px;
    padding: 0;
    text-decoration: underline;
  }
  .lobby-players {
    padding: 0;
    list-style: none;
  }
  .lobby-players li {
    padding: 12px 0;
    border-bottom: 1px solid #dce4d8;
    display: flex;
    gap: 8px;
    justify-content: space-between;
    font-size: 13px;
  }
  .lobby-players span {
    color: #617568;
  }
  .multi-table .opponent {
    min-width: 0;
  }
  .multi-table .opponent-info {
    min-width: 0;
    overflow-wrap: anywhere;
  }
  @media (max-width: 540px) {
    .multi-table .opponents {
      align-items: start;
    }
    .multi-table .opponent {
      flex: 1;
    }
    .multi-table .opponent-info strong {
      font-size: 10px;
    }
    .multi-table .opponent-info span {
      font-size: 8px;
    }
    .multi-table .table-center {
      top: 180px;
    }
    .multi-table {
      height: 450px;
    }
    .room-bar > span {
      margin-left: 0;
      width: 100%;
    }
  }
</style>
