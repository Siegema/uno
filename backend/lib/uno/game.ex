defmodule Uno.Game do
  @colors ~w(red yellow green blue)
  def colors, do: @colors

  defp card(color, value),
    do: %{
      id: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false),
      color: color,
      value: value
    }

  defp shuffle(cards), do: Enum.sort_by(cards, fn _ -> :crypto.strong_rand_bytes(16) end)

  def new(players) do
    deck =
      for color <- @colors,
          value <- ["0"] ++ Enum.flat_map(~w(1 2 3 4 5 6 7 8 9 skip reverse draw2), &[&1, &1]),
          do: card(color, value)

    deck = shuffle(deck ++ for(value <- ~w(wild wild4), _ <- 1..4, do: card("wild", value)))

    {players, deck} =
      Enum.map_reduce(players, deck, fn p, cards ->
        {hand, rest} = Enum.split(cards, 7)
        {Map.put(p, :hand, hand), rest}
      end)

    first = Enum.find(deck, &(&1.color != "wild" and &1.value in ~w(0 1 2 3 4 5 6 7 8 9)))

    %{
      players: players,
      deck: List.delete(deck, first),
      discard: [first],
      current: 0,
      direction: 1,
      color: first.color,
      drawn: nil,
      uno: false,
      winner: nil,
      log: ["Game started."]
    }
  end

  def current(g), do: Enum.at(g.players, g.current)

  def playable(g) do
    if g.winner do
      []
    else
      Enum.filter(current(g).hand, fn c ->
        (is_nil(g.drawn) or c.id == g.drawn) and legal?(g, c)
      end)
    end
  end

  defp legal?(g, %{value: "wild4"}), do: not Enum.any?(current(g).hand, &(&1.color == g.color))
  defp legal?(_g, %{value: "wild"}), do: true
  defp legal?(g, c), do: c.color == g.color or c.value == hd(g.discard).value
  defp log(g, text), do: %{g | log: Enum.take([text | g.log], 20)}
  defp next(g, steps \\ 1), do: Integer.mod(g.current + g.direction * steps, length(g.players))
  defp advance(g, steps \\ 1), do: %{g | current: next(g, steps), drawn: nil, uno: false}

  defp take(%{deck: [], discard: [top | rest]} = g) when rest != [],
    do: take(%{g | deck: shuffle(rest), discard: [top]})

  defp take(%{deck: []} = g), do: {nil, g}
  defp take(%{deck: [card | rest]} = g), do: {card, %{g | deck: rest}}

  defp add_card(g, index, card),
    do: update_in(g.players, &List.update_at(&1, index, fn p -> %{p | hand: [card | p.hand]} end))

  defp penalty(g, index, count) do
    Enum.reduce(1..count, {g, 0}, fn _, {acc, n} ->
      case take(acc) do
        {nil, acc} -> {acc, n}
        {card, acc} -> {add_card(acc, index, card), n + 1}
      end
    end)
  end

  def action(g, "uno", _) do
    if length(current(g).hand) == 2 and not g.uno do
      {:ok, log(%{g | uno: true}, "#{current(g).name} called UNO.")}
    else
      {:error, "UNO can be called once when you have two cards."}
    end
  end

  def action(g, "draw", _) do
    if g.drawn do
      {:error, "Play the drawn card or pass."}
    else
      case take(g) do
        {nil, g} ->
          {:ok, g |> log("#{current(g).name} could not draw and passed.") |> advance()}

        {card, g} ->
          g = g |> add_card(g.current, card) |> log("#{current(g).name} drew a card.")
          {:ok, if(legal?(g, card), do: %{g | drawn: card.id}, else: advance(g))}
      end
    end
  end

  def action(g, "pass", _) do
    if g.drawn,
      do: {:ok, g |> log("#{current(g).name} passed.") |> advance()},
      else: {:error, "You must draw before passing."}
  end

  def action(g, "play", params) do
    card = Enum.find(playable(g), &(&1.id == params["cardId"]))
    color = params["color"]

    cond do
      is_nil(card) ->
        {:error, "That card cannot be played."}

      card.color == "wild" and color not in @colors ->
        {:error, "Choose a valid color."}

      true ->
        player = current(g)

        g =
          update_in(
            g.players,
            &List.update_at(&1, g.current, fn p ->
              %{p | hand: Enum.reject(p.hand, fn c -> c.id == card.id end)}
            end)
          )

        g = %{
          g
          | discard: [card | g.discard],
            color: if(card.color == "wild", do: color, else: card.color)
        }

        g = log(g, "#{player.name} played #{card.color} #{card.value}.")

        g =
          if length(current(g).hand) == 1 and not g.uno do
            {g, n} = penalty(g, g.current, 2)
            log(g, "#{player.name} missed UNO and drew #{n}.")
          else
            g
          end

        g = if card.value == "reverse", do: %{g | direction: -g.direction}, else: g

        {g, steps} =
          cond do
            card.value in ~w(draw2 wild4) ->
              target = next(g)
              {g, n} = penalty(g, target, if(card.value == "draw2", do: 2, else: 4))
              {log(g, "#{Enum.at(g.players, target).name} drew #{n} and was skipped."), 2}

            card.value == "skip" or (card.value == "reverse" and length(g.players) == 2) ->
              {g, 2}

            true ->
              {g, 1}
          end

        if current(g).hand == [] do
          {:ok,
           g
           |> Map.merge(%{winner: player.id, drawn: nil, uno: false})
           |> log("#{player.name} wins!")}
        else
          {:ok, advance(g, steps)}
        end
    end
  end

  def action(_, _, _), do: {:error, "Unknown action."}
end
