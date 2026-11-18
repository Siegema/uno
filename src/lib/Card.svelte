<script lang="ts">
  import type { Color, Value } from "./game";
  type DisplayCard = {
    id: string | number;
    color: Color | "wild";
    value: Value;
  };
  const cardLabel = (card: DisplayCard) => {
    if (card.value === "wild") return "Wild";
    if (card.value === "wild4") return "Wild draw four";
    const color = card.color.charAt(0).toUpperCase() + card.color.slice(1);
    return `${color} ${card.value === "draw2" ? "draw two" : card.value}`;
  };
  let {
    card,
    playable = false,
    disabled = false,
    onclick,
    display = false,
  }: {
    card: DisplayCard;
    playable?: boolean;
    disabled?: boolean;
    onclick?: () => void;
    display?: boolean;
  } = $props();
  let symbol = $derived(
    card.value === "skip"
      ? "⊘"
      : card.value === "reverse"
        ? "↻"
        : card.value === "draw2"
          ? "+2"
          : card.value === "wild4"
            ? "+4"
            : card.value === "wild"
              ? "W"
              : card.value,
  );
</script>

{#if display}
  <div
    class="playing-card {card.color} display-card"
    aria-label={cardLabel(card)}
    role="img"
  >
    <span class="corner top">{symbol}</span><span class="card-oval">
      <span>{symbol}</span>
    </span><span class="corner bottom">{symbol}</span>
  </div>
{:else}
  <button
    class="playing-card {card.color}"
    class:playable
    class:muted={disabled}
    aria-disabled={disabled}
    onclick={() => {
      if (!disabled) onclick?.();
    }}
    aria-label="{cardLabel(card)}{disabled ? ' (not playable)' : ''}"
    title={cardLabel(card)}
  >
    <span class="corner top">{symbol}</span><span class="card-oval">
      <span>{symbol}</span>
    </span><span class="corner bottom">{symbol}</span>
    <span class="card-color-label">{card.color}</span>
  </button>
{/if}
