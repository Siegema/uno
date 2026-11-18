defmodule Uno.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Uno.PubSub},
      {Registry, keys: :unique, name: Uno.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Uno.RoomSupervisor},
      Uno.Lobby,
      UnoWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Uno.Supervisor)
  end

  def config_change(changed, _new, removed), do: UnoWeb.Endpoint.config_change(changed, removed)
end
