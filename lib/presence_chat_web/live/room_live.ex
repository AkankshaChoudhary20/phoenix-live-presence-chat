defmodule PresenceChatWeb.RoomLive do
  @moduledoc """
  A single LiveView page for a chat room: enter a display name, see who
  else is present, and exchange messages in real time.

  The realtime plumbing here is intentionally NOT javascript. Every update
  -- another user joining, a tab closing, a new chat message -- is pushed
  from the server as a diff of server-rendered HTML over the existing
  LiveView websocket connection:

    * `PresenceChatWeb.Presence` (a `Phoenix.Presence`/`Phoenix.Tracker`
      process) tracks this LiveView process under the room's topic. When
      the socket disconnects (tab closed, network drop) Presence detects
      the process going down and untracks it automatically -- there is no
      manual "user left" bookkeeping.
    * `Phoenix.PubSub` broadcasts `"presence_diff"` events (from Presence)
      and `{:new_message, message}` events (from `send_message` below) to
      every LiveView process subscribed to the room's topic, including
      ones on other BEAM nodes in a cluster.
    * Each subscribed LiveView receives those as ordinary messages in
      `handle_info/2`, updates its assigns, and Phoenix re-renders only
      the parts of the template that changed, pushing the diff down the
      socket.
  """

  use PresenceChatWeb, :live_view

  alias PresenceChat.Chat.Message
  alias PresenceChatWeb.Presence

  @pubsub PresenceChat.PubSub
  @max_messages 50

  @impl true
  def mount(params, _session, socket) do
    room_id = normalize_room_id(params["room_id"])
    topic = topic_for(room_id)

    socket =
      assign(socket,
        room_id: room_id,
        topic: topic,
        joined?: false,
        display_name: nil,
        messages: [],
        presences: [],
        message_input: ""
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("join", %{"display_name" => raw_name}, socket) do
    name = Message.format_display_name(raw_name)
    topic = socket.assigns.topic

    # Phoenix.Presence.track/4 registers *this LiveView process* (self())
    # under `topic`, keyed by the unique socket id, with `name` as its
    # metadata. This is the real presence mechanism -- if the process
    # dies (tab closed), Phoenix.Tracker notices and broadcasts a
    # "presence_diff" leave automatically.
    {:ok, _ref} =
      Presence.track(self(), topic, socket.id, %{
        name: name,
        joined_at: System.system_time(:second)
      })

    :ok = Phoenix.PubSub.subscribe(@pubsub, topic)

    socket =
      socket
      |> assign(joined?: true, display_name: name, presences: list_presences(topic))
      |> broadcast_system_message("#{name} joined the room.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"body" => body}, socket) do
    case Message.validate_body(body) do
      {:ok, clean_body} ->
        broadcast_message(socket, socket.assigns.display_name, clean_body, system?: false)
        {:noreply, assign(socket, message_input: "")}

      {:error, _reason} ->
        # Leave whatever the user typed in place (minus the blank/too-long
        # case, which just gets dropped) -- there's no persisted error UI
        # in this tight-scope demo.
        {:noreply, assign(socket, message_input: "")}
    end
  end

  # Fired by Phoenix.Presence (via PubSub) whenever someone joins or
  # leaves this room's topic, on this node or any other connected node.
  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, presences: list_presences(socket.assigns.topic))}
  end

  # Fired for every chat message broadcast to this room's topic.
  def handle_info({:new_message, message}, socket) do
    messages = (socket.assigns.messages ++ [message]) |> Enum.take(-@max_messages)
    {:noreply, assign(socket, messages: messages)}
  end

  defp broadcast_message(socket, name, body, opts) do
    message = %{
      name: name,
      body: body,
      at: System.system_time(:second),
      system?: Keyword.fetch!(opts, :system?)
    }

    Phoenix.PubSub.broadcast(@pubsub, socket.assigns.topic, {:new_message, message})
  end

  defp broadcast_system_message(socket, text) do
    broadcast_message(socket, nil, text, system?: true)
    socket
  end

  defp list_presences(topic) do
    topic
    |> Presence.list()
    |> Enum.map(fn {_key, %{metas: [meta | _]}} -> meta end)
    |> Enum.sort_by(& &1.joined_at)
  end

  defp topic_for(room_id), do: "room:#{room_id}"

  defp normalize_room_id(nil), do: "lobby"
  defp normalize_room_id(""), do: "lobby"
  defp normalize_room_id(room_id) when is_binary(room_id), do: room_id
end
