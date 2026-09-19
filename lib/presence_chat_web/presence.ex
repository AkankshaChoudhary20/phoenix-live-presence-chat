defmodule PresenceChatWeb.Presence do
  @moduledoc """
  Tracks connected users per chat room using `Phoenix.Presence`.

  This is backed by `Phoenix.Tracker`, a CRDT-based, distributed process
  registry that ships with Phoenix -- not a hand-rolled list in process
  state. It survives netsplits, dedupes across nodes in a cluster, and
  broadcasts `"presence_diff"` events over the given `pubsub_server`
  whenever someone joins or leaves a topic, which is what lets every
  connected `RoomLive` process update its "who's here" list in real time.
  """

  use Phoenix.Presence,
    otp_app: :presence_chat,
    pubsub_server: PresenceChat.PubSub
end
