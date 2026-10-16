defmodule PresenceChatWeb.RoomLiveTest do
  use ExUnit.Case, async: true
  alias PresenceChatWeb.RoomLive

  test "an unjoined socket cannot publish a chat message" do
    topic = "room:unjoined-#{System.unique_integer([:positive])}"
    :ok = Phoenix.PubSub.subscribe(PresenceChat.PubSub, topic)
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, joined?: false, topic: topic, display_name: nil, message_input: "draft"}}
    assert {:noreply, ^socket} = RoomLive.handle_event("send_message", %{"body" => "hello"}, socket)
    refute_receive {:new_message, _}, 50
  end

  test "joining twice leaves the existing socket and identity unchanged" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, joined?: true, display_name: "Alice"}}
    assert {:noreply, ^socket} = RoomLive.handle_event("join", %{"display_name" => "Other"}, socket)
  end
end
