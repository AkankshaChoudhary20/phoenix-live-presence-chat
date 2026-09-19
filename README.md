# phoenix-live-presence-chat

A single-page, multi-user chat room built with Phoenix LiveView. Open it in
two browser tabs: each one shows a live "who's here" list and a shared
message feed that updates instantly in both tabs — with **zero
application JavaScript**. Every update is a server-rendered HTML diff
pushed down a websocket by the BEAM process backing your tab.

## Why this exists

Most "realtime chat" demos reach for a JS framework plus polling, a
websocket library, and hand-rolled client-side state. LiveView takes a
different approach: your browser tab is represented by a live Elixir
process on the server. State changes on the server (someone joins, someone
sends a message) get diffed against the last render and pushed to the
client as minimal HTML patches. The client just applies them — no fetch
loops, no client-side store to keep in sync.

The two pieces of OTP machinery doing the actual work here are the point
of the demo:

- **`Phoenix.Presence`** — a CRDT-backed, distributed process registry
  (built on `Phoenix.Tracker`) that tracks which LiveView processes are
  "present" under a topic. When a tab closes, the process behind it dies,
  and Presence detects that and broadcasts a leave automatically. There is
  no manual "remove user from list" code anywhere in this project.
- **`Phoenix.PubSub`** — broadcasts both Presence's own `"presence_diff"`
  events and this app's `{:new_message, message}` chat events to every
  subscribed LiveView process, on this node or (unmodified) across a
  cluster of nodes.

## Architecture

```
        Browser tab A                          Browser tab B
        (renders HTML,                         (renders HTML,
         no app JS)                              no app JS)
             |  websocket                             |  websocket
             v  (LiveView diffs)                       v
   +-------------------+                   +-------------------+
   |  RoomLive process |                   |  RoomLive process |
   |  (per-connection   |                   |  (per-connection   |
   |   Elixir process)  |                   |   Elixir process)  |
   +----------+----------+                   +----------+----------+
              |     ^                                    |     ^
   track/list |     | handle_info                        |     |
              v     |    (presence_diff, {:new_message,_})|     |
   +-----------------------------------------------------------------+
   |                      Phoenix.PubSub  (PresenceChat.PubSub)       |
   |   topic "room:lobby": presence_diff events + chat broadcasts     |
   +-----------------------------------------------------------------+
              ^                                                ^
              |                                                |
   +-------------------------+                                 |
   |  PresenceChatWeb.Presence |-------------------------------+
   |  (Phoenix.Tracker-backed  |   tracks {self(), topic, meta}
   |   distributed registry)   |   broadcasts presence_diff on join/leave
   +---------------------------+
```

Flow for a chat message: user submits the form → `RoomLive` validates the
body in `PresenceChat.Chat.Message` (pure function, no process state) →
`Phoenix.PubSub.broadcast/3` sends `{:new_message, message}` to the room's
topic → **every** subscribed `RoomLive` process (including the sender's)
receives it in `handle_info/2`, appends it to its `messages` assign, and
LiveView re-renders just the new `<div class="message">` into the DOM.

Flow for presence: on joining, `RoomLive` calls `Presence.track/4` to
register itself under the room topic with `%{name: name, joined_at: ...}`
metadata, then subscribes to that topic. Any join/leave (including a tab
closing, detected by the tracked process going down) causes Presence to
broadcast a `"presence_diff"`, which every `RoomLive` process handles by
recomputing its `presences` assign from `Presence.list/1`.

## Features

- Enter a display name to join a shared room (`/` defaults to the
  `"lobby"` room; `/rooms/:room_id` joins any named room).
- Live "who's here" panel — updates the instant someone joins or their tab
  disconnects, with no polling.
- Shared, ephemeral chat feed — messages broadcast to everyone in the room
  in real time, capped to the last 50 messages per room (in-memory only,
  nothing persisted, nothing to clean up).
- System messages ("X joined the room") flow through the exact same
  broadcast path as chat messages.
- Message validation/sanitization (blank/oversized rejection, whitespace
  normalization) as a small pure module, independent of any LiveView or
  process state.
- No client-side JavaScript beyond loading Phoenix's own LiveView client
  library (from a CDN, so the project needs nothing but the BEAM — no
  Node/esbuild toolchain).

## Project layout

```
lib/
  presence_chat/
    application.ex        # Supervision tree: PubSub, Presence, Endpoint
    chat/message.ex        # Pure logic: validate_body/1, sanitize/1,
                            # format_display_name/1 -- the unit-tested part
  presence_chat_web/
    presence.ex             # `use Phoenix.Presence` -- the real tracker
    endpoint.ex              # Plug pipeline, websocket socket mount
    router.ex                # `live "/"` and `live "/rooms/:room_id"`
    telemetry.ex             # Standard Phoenix telemetry supervisor
    live/
      room_live.ex           # The LiveView: mount/join/send_message/
                              # handle_info(presence_diff | new_message)
      room_live.html.heex    # Name-entry form + presence list + chat UI
    components/layouts.ex + layouts/root.html.heex, app.html.heex
    controllers/error_html.ex + error_html/404.html.heex, 500.html.heex
  presence_chat_web.ex        # `use PresenceChatWeb, :live_view` etc.
test/
  presence_chat/chat/message_test.exs  # ExUnit tests + doctests for the
                                         # pure validation/formatting logic
config/                        # config.exs, dev.exs, test.exs, prod.exs,
                                # runtime.exs
priv/static/assets/app.css     # Hand-written CSS, no build step
mix.exs
```

## Honest verification notes

This sandbox does not have Elixir/Erlang installed, and Docker's first-time
`elixir:1.16` image pull plus a cold `mix deps.get` (Hex, Phoenix,
LiveView, Bandit, and their transitive deps) did not finish inside a
~4-minute budget — it was still resolving/fetching when the budget ran
out, so it was backgrounded and then abandoned rather than let run
indefinitely.

**As a result, this code has not been compiled or run.** It was
hand-written directly (no `mix phx.new` scaffold was generated) to be
idiomatic, current (Phoenix 1.7.14 / LiveView 0.20.17 conventions:
verified routes, function-component layouts, the `Bandit.PhoenixAdapter`),
and internally consistent — module names, `use` macros, config keys, and
the `Phoenix.Presence`/`Phoenix.PubSub` message shapes (`%{event:
"presence_diff", payload: diff}` and `{:new_message, message}`) all match
documented Phoenix/LiveView APIs — but there has been no compiler, no
`mix test`, and no running BEAM to catch a typo, an arity mismatch, or a
version-specific API drift.

If you have Elixir 1.15+/OTP 26+ installed, the fastest way to actually
verify it:

```bash
mix deps.get
mix test      # exercises test/presence_chat/chat/message_test.exs + doctests
mix phx.server
```

Then open `http://localhost:4000` in two browser tabs (or windows) with
different display names.

## What would make this "production" rather than "demo"

- Presence metadata and chat history are entirely in-memory per LiveView
  process / per `Phoenix.Tracker` — restart the app and every room is
  empty again. That's intentional here (no persistence was in scope), but
  a real deployment would want at least a short-lived message history
  store (e.g. an ETS table or Redis) so a page refresh doesn't lose the
  last few messages.
- No auth beyond picking a display name — anyone can claim any name,
  including someone else's.
- Single-node PubSub as configured; clustering (`libcluster` +
  distributed Erlang) would let rooms span multiple BEAM nodes with zero
  code changes to the LiveView itself, since `Phoenix.PubSub` and
  `Phoenix.Presence` are already cluster-aware.
