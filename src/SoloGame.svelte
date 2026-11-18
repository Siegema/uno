<script lang="ts">
  import CardView from "./lib/Card.svelte";
  import {
    COLORS,
    createGame,
    getPlayableCards,
    playCard,
    drawCard,
    passTurn,
    callUno,
    takeBotTurn,
    type Card,
    type Color,
  } from "./lib/game";

  let game = $state(createGame());
  let rulesDialog: HTMLDialogElement;
  let restartDialog: HTMLDialogElement;
  let colorDialog: HTMLDialogElement;
  let dialogOpen = $state(false);
  let chosenCard = $state<Card | null>(null);
  let playable = $derived(
    game.currentPlayer === 0 ? getPlayableCards(game) : [],
  );
  let isHumanTurn = $derived(game.currentPlayer === 0 && game.winner === null);
  let topCard = $derived(game.discardPile[game.discardPile.length - 1]);
  let status = $derived(
    game.winner !== null
      ? `${game.players[game.winner].name} ${game.winner === 0 ? "win" : "wins"}!`
      : isHumanTurn
        ? game.drawnCardId !== null
          ? "Play your drawn card or pass"
          : "Your move"
        : `${game.players[game.currentPlayer].name} is thinking…`,
  );

  $effect(() => {
    if (game.winner !== null || game.currentPlayer === 0 || dialogOpen) return;
    const timer = setTimeout(() => {
      game = takeBotTurn(game);
    }, 950);
    return () => clearTimeout(timer);
  });

  function openDialog(dialog: HTMLDialogElement) {
    dialogOpen = true;
    dialog.showModal();
  }
  function closeDialog(dialog: HTMLDialogElement) {
    dialog.close();
  }
  function selectCard(card: Card) {
    if (!isHumanTurn || !playable.some((item) => item.id === card.id)) return;
    if (card.color === "wild") {
      chosenCard = card;
      openDialog(colorDialog);
    } else game = playCard(game, card.id);
  }
  function chooseColor(color: Color) {
    if (chosenCard) game = playCard(game, chosenCard.id, color);
    chosenCard = null;
    closeDialog(colorDialog);
  }
  function restart() {
    game = createGame();
    closeDialog(restartDialog);
  }
</script>

<svelte:head><meta name="theme-color" content="#f7f5ef" /></svelte:head>

<div class="site-shell">
  <header class="site-header">
    <a class="brand" href="#top" aria-label="UNO Club home">
      <span class="brand-mark"><i></i><b>u</b></span><span>
        uno<span class="brand-light"> club</span><small>
          THE GOOD TIME CARD CLUB
        </small>
      </span>
    </a>
    <div class="header-actions">
      <button class="text-button" onclick={() => openDialog(rulesDialog)}>
        HOW TO PLAY <span>↗</span>
      </button><button
        class="outline-button"
        onclick={() => openDialog(restartDialog)}
      >
        <span>↻</span> New game
      </button>
    </div>
  </header>

  <main id="top">
    <section class="intro">
      <div>
        <p class="eyebrow"><span>✳</span> GOOD CARDS. GREAT COMPANY.</p>
        <h1>Your table is ready<span>.</span></h1>
        <p class="subtitle">A little friendly competition looks good on you.</p>
      </div>
      <div class="friends-pill">
        <span>✳</span> YOU + 3 FRIENDLY BOTS
        <span class="sr-only">Computer opponents</span>
      </div>
    </section>

    <div class="game-layout">
      <section class="game-main" aria-label="UNO game table">
        <div class="table">
          <div class="table-border"></div>
          <div class="table-rings"></div>
          <div class="table-top">
            <span>THE UNO CLUB <span class="tiny-star">✳</span></span><span>
              EST. FOR GOOD TIMES
            </span>
          </div>
          <div class="opponents">
            {#each [1, 2, 3] as index}
              <div
                class:active={game.currentPlayer === index &&
                  game.winner === null}
                class="opponent"
              >
                <div class="avatar avatar-{index}" aria-hidden="true">
                  {index === 1 ? "☺" : index === 2 ? "✿" : "☻"}
                </div>
                <div class="opponent-info">
                  <strong>{game.players[index].name}</strong><span>
                    {game.players[index].hand.length} cards
                  </span>
                </div>
                <div class="mini-fan" aria-hidden="true">
                  <i></i><i></i><i></i>
                </div>
              </div>
            {/each}
          </div>
          <div class="table-center">
            <div class="pile-wrap">
              <button
                class="deck"
                aria-label="Draw a card"
                title="Draw a card"
                disabled={!isHumanTurn || game.drawnCardId !== null}
                onclick={() => (game = drawCard(game))}
              >
                <span>UNO</span>
              </button><span class="pile-label">DRAW PILE</span>
            </div>
            <div class="center-plus">✳</div>
            <div class="pile-wrap">
              <CardView card={topCard} display /><span class="pile-label">
                DISCARD PILE
              </span>
            </div>
          </div>
          <div class="table-bottom">
            <div class="color-badge">
              <span class="color-dot {game.currentColor}"></span> ACTIVE COLOR
              <strong>{game.currentColor}</strong>
            </div>
            <div class="direction">
              {game.direction === 1 ? "↻" : "↺"}
              <span>
                {game.direction === 1 ? "CLOCKWISE" : "COUNTERCLOCKWISE"}
              </span>
            </div>
          </div>
          <div class="your-seat">
            <span class="your-avatar">☺</span><span>
              <strong>You</strong><small>
                {isHumanTurn ? "YOUR TURN" : "AT THE TABLE"}
              </small>
            </span><i class:lit={isHumanTurn}></i>
          </div>
        </div>

        <div class="hand-section">
          <div class="hand-heading">
            <div>
              <span class="section-kicker">YOUR HAND</span><span
                class="hand-count"
              >
                {game.players[0].hand.length} cards
              </span>
            </div>
            <div class="turn-status" aria-live="polite">
              <span></span>{status}
            </div>
          </div>
          <div class="hand-content">
            <div class="hand-scroll" aria-label="Your cards">
              {#each game.players[0].hand as card (card.id)}<CardView
                  {card}
                  playable={playable.some((item) => item.id === card.id)}
                  disabled={!isHumanTurn ||
                    !playable.some((item) => item.id === card.id)}
                  onclick={() => selectCard(card)}
                />{/each}
            </div>
            <button
              class="uno-button"
              class:armed={game.unoArmed}
              disabled={!isHumanTurn ||
                game.players[0].hand.length !== 2 ||
                game.unoArmed}
              onclick={() => (game = callUno(game))}
            >
              {game.unoArmed ? "UNO ✓" : "UNO!"}
            </button>
          </div>
          <div class="hand-footer">
            <p>
              {game.unoArmed
                ? "UNO called! Now play your card."
                : isHumanTurn && game.players[0].hand.length === 2
                  ? "Call UNO before playing down to one card!"
                  : game.drawnCardId !== null && isHumanTurn
                    ? "Only your newly drawn card can be played."
                    : "Match the color or symbol, or play a wild."}
            </p>
            <button
              class="draw-button"
              disabled={!isHumanTurn}
              onclick={() =>
                (game =
                  game.drawnCardId !== null ? passTurn(game) : drawCard(game))}
            >
              {game.drawnCardId !== null && isHumanTurn
                ? "Keep card / Pass"
                : "Draw a card"} <span>↗</span>
            </button>
          </div>
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
          {#each game.log.slice(0, 5) as entry, i}<div class="activity">
              <span class:latest={i === 0} class="activity-dot"></span>
              <p>{entry}<small>{i === 0 ? "JUST NOW" : "EARLIER"}</small></p>
            </div>{/each}
        </div>
        <div class="tip">
          <span>✳ &nbsp; A LITTLE REMINDER</span>
          <p>
            Down to two cards? Call <strong>UNO!</strong> before you play your next
            one.
          </p>
        </div>
        <div class="sidebar-bottom">GOOD GAME, GOOD COMPANY <span>☺</span></div>
      </aside>
    </div>
    <footer>
      <span>MADE FOR PLAYING TOGETHER <b>✳</b></span><span>
        NO BAD HANDS, JUST GOOD STORIES.
      </span>
    </footer>
  </main>
</div>

<dialog
  bind:this={rulesDialog}
  onclose={() => (dialogOpen = false)}
  aria-labelledby="rules-title"
>
  <div class="dialog-content">
    <button
      class="close-dialog"
      aria-label="Close rules"
      onclick={() => closeDialog(rulesDialog)}
    >
      ×
    </button>
    <p class="eyebrow">THE FRIENDLY RULEBOOK</p>
    <h2 id="rules-title">How to play<span>.</span></h2>
    <p>
      Be the first to play all your cards. Match the top card by color or
      symbol, or play a wild and pick the next color.
    </p>
    <ul>
      <li>
        Draw one card on your turn. If it plays, you can play it or keep it and
        pass; otherwise your turn ends.
      </li>
      <li>
        Skip skips the next player; reverse changes direction. Draw two and wild
        draw four make the next player draw and skip their turn.
      </li>
      <li>
        Play wild draw four only if you have no card of the active color. No
        stacking or challenges.
      </li>
      <li>
        <strong>House rule:</strong> call UNO before playing from two cards to one,
        or immediately draw two cards. Bots call automatically.
      </li>
    </ul>
    <button class="dialog-primary" onclick={() => closeDialog(rulesDialog)}>
      Got it, let's play
    </button>
  </div>
</dialog>
<dialog
  bind:this={restartDialog}
  onclose={() => (dialogOpen = false)}
  aria-labelledby="restart-title"
>
  <div class="dialog-content">
    <p class="eyebrow">A FRESH DEAL</p>
    <h2 id="restart-title">Start a new game<span>?</span></h2>
    <p>Your current game will be left behind. Ready for a fresh hand?</p>
    <div class="dialog-actions">
      <button class="outline-button" onclick={() => closeDialog(restartDialog)}>
        Keep playing
      </button><button class="dialog-primary" onclick={restart}>
        New game
      </button>
    </div>
  </div>
</dialog>
<dialog
  bind:this={colorDialog}
  onclose={() => {
    dialogOpen = false;
    chosenCard = null;
  }}
  aria-labelledby="color-title"
>
  <div class="dialog-content">
    <p class="eyebrow">MAKE IT YOURS</p>
    <h2 id="color-title">Pick a color<span>.</span></h2>
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
      onclick={() => closeDialog(colorDialog)}
    >
      Cancel
    </button>
  </div>
</dialog>
{#if game.winner !== null}<div class="winner-banner" role="status">
    <span>✳</span>
    <div>
      <strong>
        {game.winner === 0
          ? "You won the table!"
          : `${game.players[game.winner].name} takes the win!`}
      </strong><small>Good game, everyone. Ready for another?</small>
    </div>
    <button onclick={() => (game = createGame())}>Play again ↗</button>
  </div>{/if}
