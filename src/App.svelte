<script lang="ts">
  import SoloGame from "./SoloGame.svelte";
  import Multiplayer from "./Multiplayer.svelte";
  const initialRoom = new URLSearchParams(window.location.search).get("room");
  let mode = $state<"solo" | "friends">(initialRoom ? "friends" : "solo");
</script>

<nav class="mode-nav" aria-label="Game mode">
  <button
    class:active={mode === "solo"}
    aria-pressed={mode === "solo"}
    onclick={() => (mode = "solo")}
  >
    Solo
  </button>
  <button
    class:active={mode === "friends"}
    aria-pressed={mode === "friends"}
    onclick={() => (mode = "friends")}
  >
    Play with friends
  </button>
</nav>
{#if mode === "solo"}<SoloGame />{:else}<Multiplayer />{/if}

<style>
  .mode-nav {
    max-width: 1440px;
    margin: 12px auto 0;
    padding: 0 6.1%;
    display: flex;
    gap: 8px;
  }
  .mode-nav button {
    border: 1px solid #cbd8ca;
    border-radius: 20px;
    padding: 8px 15px;
    background: transparent;
    color: #344238;
    font-size: 12px;
    font-weight: 800;
  }
  .mode-nav button.active {
    background: #244d37;
    border-color: #244d37;
    color: white;
  }
</style>
