export type Color = "red" | "yellow" | "green" | "blue";
export type Value =
  | "0"
  | "1"
  | "2"
  | "3"
  | "4"
  | "5"
  | "6"
  | "7"
  | "8"
  | "9"
  | "skip"
  | "reverse"
  | "draw2"
  | "wild"
  | "wild4";
export interface Card {
  id: number;
  color: Color | "wild";
  value: Value;
}
export interface Player {
  name: string;
  hand: Card[];
}
export interface GameState {
  players: Player[];
  drawPile: Card[];
  discardPile: Card[];
  currentPlayer: number;
  direction: 1 | -1;
  currentColor: Color;
  drawnCardId: number | null;
  unoArmed: boolean;
  winner: number | null;
  log: string[];
  turn: number;
}

export const COLORS: Color[] = ["red", "yellow", "green", "blue"];

function shuffle<T>(items: T[]): T[] {
  const result = items.slice();
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

function copy(game: GameState): GameState {
  return {
    ...game,
    players: game.players.map((player) => ({
      ...player,
      hand: player.hand.slice(),
    })),
    drawPile: game.drawPile.slice(),
    discardPile: game.discardPile.slice(),
    log: game.log.slice(),
  };
}

function log(game: GameState, message: string): void {
  game.log.unshift(message);
  game.log = game.log.slice(0, 20);
}

function next(game: GameState, from: number, steps = 1): number {
  return (
    (from +
      ((game.direction * steps) % game.players.length) +
      game.players.length) %
    game.players.length
  );
}

function advance(game: GameState, steps = 1): void {
  game.currentPlayer = next(game, game.currentPlayer, steps);
  game.drawnCardId = null;
  game.unoArmed = false;
  game.turn++;
}

function takeFromPile(game: GameState): Card | undefined {
  if (game.drawPile.length === 0 && game.discardPile.length > 1) {
    const top = game.discardPile[game.discardPile.length - 1];
    game.drawPile = shuffle(game.discardPile.slice(0, -1));
    game.discardPile = [top];
  }
  return game.drawPile.pop();
}

function penalty(game: GameState, playerIndex: number, count: number): number {
  let drawn = 0;
  while (drawn < count) {
    const card = takeFromPile(game);
    if (!card) break;
    game.players[playerIndex].hand.push(card);
    drawn++;
  }
  return drawn;
}

export function createGame(): GameState {
  const deck: Card[] = [];
  let id = 0;
  for (const color of COLORS) {
    deck.push({ id: id++, color, value: "0" });
    const values: Value[] = [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "skip",
      "reverse",
      "draw2",
    ];
    for (const value of values) {
      deck.push({ id: id++, color, value }, { id: id++, color, value });
    }
  }
  for (let i = 0; i < 4; i++) {
    deck.push(
      { id: id++, color: "wild", value: "wild" },
      { id: id++, color: "wild", value: "wild4" },
    );
  }
  const drawPile = shuffle(deck);
  const players = ["You", "Milo", "Luna", "Jasper"].map((name) => ({
    name,
    hand: drawPile.splice(-7),
  }));
  const numberIndex = drawPile.findIndex(
    (card) => card.color !== "wild" && /^[0-9]$/.test(card.value),
  );
  const [first] = drawPile.splice(numberIndex, 1);
  return {
    players,
    drawPile,
    discardPile: [first],
    currentPlayer: 0,
    direction: 1,
    currentColor: first.color as Color,
    drawnCardId: null,
    unoArmed: false,
    winner: null,
    log: [`Game started with ${cardLabel(first)}.`],
    turn: 1,
  };
}

function isPlayable(game: GameState, card: Card): boolean {
  if (card.value === "wild4") {
    return !game.players[game.currentPlayer].hand.some(
      (other) => other.color !== "wild" && other.color === game.currentColor,
    );
  }
  if (card.value === "wild") return true;
  const top = game.discardPile[game.discardPile.length - 1];
  return card.color === game.currentColor || card.value === top.value;
}

export function getPlayableCards(game: GameState): Card[] {
  if (game.winner !== null) return [];
  return game.players[game.currentPlayer].hand.filter(
    (card) =>
      (game.drawnCardId === null || card.id === game.drawnCardId) &&
      isPlayable(game, card),
  );
}

export function playCard(
  game: GameState,
  cardId: number,
  chosenColor?: Color,
): GameState {
  if (game.winner !== null) return game;
  const card = getPlayableCards(game).find(
    (candidate) => candidate.id === cardId,
  );
  if (
    !card ||
    (card.color === "wild" && (!chosenColor || !COLORS.includes(chosenColor)))
  )
    return game;
  const result = copy(game);
  const playerIndex = result.currentPlayer;
  const player = result.players[playerIndex];
  player.hand = player.hand.filter((candidate) => candidate.id !== cardId);
  result.discardPile.push(card);
  result.currentColor = card.color === "wild" ? chosenColor! : card.color;
  log(
    result,
    `${player.name} played ${cardLabel(card)}${card.color === "wild" ? ` and chose ${result.currentColor}` : ""}.`,
  );

  if (player.hand.length === 1) {
    if (playerIndex !== 0 || result.unoArmed) {
      log(result, `${player.name} called UNO!`);
    } else {
      const drawn = penalty(result, playerIndex, 2);
      log(
        result,
        `${player.name} missed UNO and drew ${drawn} card${drawn === 1 ? "" : "s"}.`,
      );
    }
  }

  if (card.value === "reverse")
    result.direction = result.direction === 1 ? -1 : 1;
  let steps = card.value === "skip" ? 2 : 1;
  if (card.value === "draw2" || card.value === "wild4") {
    const target = next(result, playerIndex);
    const drawn = penalty(result, target, card.value === "draw2" ? 2 : 4);
    log(
      result,
      `${result.players[target].name} drew ${drawn} card${drawn === 1 ? "" : "s"} and was skipped.`,
    );
    steps = 2;
  }
  if (player.hand.length === 0) {
    result.winner = playerIndex;
    result.drawnCardId = null;
    result.unoArmed = false;
    log(result, `${player.name} wins!`);
  } else {
    advance(result, steps);
  }
  return result;
}

export function drawCard(game: GameState): GameState {
  if (game.winner !== null || game.drawnCardId !== null) return game;
  const result = copy(game);
  const player = result.players[result.currentPlayer];
  const card = takeFromPile(result);
  if (!card) {
    log(result, `${player.name} could not draw and passed.`);
    advance(result);
    return result;
  }
  player.hand.push(card);
  log(result, `${player.name} drew a card.`);
  if (isPlayable(result, card)) {
    result.drawnCardId = card.id;
  } else {
    advance(result);
  }
  return result;
}

export function passTurn(game: GameState): GameState {
  if (game.winner !== null || game.drawnCardId === null) return game;
  const result = copy(game);
  log(result, `${result.players[result.currentPlayer].name} passed.`);
  advance(result);
  return result;
}

export function callUno(game: GameState): GameState {
  if (
    game.winner !== null ||
    game.currentPlayer !== 0 ||
    game.players[0].hand.length !== 2 ||
    game.unoArmed
  )
    return game;
  const result = copy(game);
  result.unoArmed = true;
  log(result, "You are ready to call UNO.");
  return result;
}

export function takeBotTurn(game: GameState): GameState {
  if (game.winner !== null || game.currentPlayer === 0) return game;
  let result = game;
  let playable = getPlayableCards(result);
  if (playable.length === 0 && result.drawnCardId === null) {
    result = drawCard(result);
    if (result.currentPlayer !== game.currentPlayer || result.winner !== null)
      return result;
    playable = getPlayableCards(result);
  }
  if (playable.length === 0) return passTurn(result);
  const card =
    playable.find((candidate) => candidate.color !== "wild") ?? playable[0];
  const hand = result.players[result.currentPlayer].hand;
  const color = COLORS.reduce(
    (best, candidate) =>
      hand.filter((c) => c.id !== card.id && c.color === candidate).length >
      hand.filter((c) => c.id !== card.id && c.color === best).length
        ? candidate
        : best,
    COLORS[0],
  );
  return playCard(result, card.id, color);
}

export function cardLabel(card: Card): string {
  if (card.value === "wild") return "Wild";
  if (card.value === "wild4") return "Wild draw four";
  const color = card.color.charAt(0).toUpperCase() + card.color.slice(1);
  const value = card.value === "draw2" ? "draw two" : card.value;
  return `${color} ${value}`;
}
