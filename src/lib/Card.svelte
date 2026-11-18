<script lang="ts">
  import { cardLabel, type Card } from "./game";
  let {
    card,
    playable = false,
    disabled = false,
    onclick,
    display = false,
  }: {
    card: Card;
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
