defmodule PresenceChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: PresenceChat.PubSub},
      # Tracks who is present in each chat room via Phoenix.Presence. This
      # is a real OTP process (backed by Phoenix.Tracker) replicated across
      # nodes via the PubSub server above -- not an in-memory list owned by
      # a single LiveView.
      PresenceChatWeb.Presence,
      # Telemetry polls Presence immediately, so start its dependency first.
      PresenceChatWeb.Telemetry,
      PresenceChatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PresenceChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PresenceChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
