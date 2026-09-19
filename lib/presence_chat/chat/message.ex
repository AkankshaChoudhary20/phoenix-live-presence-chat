defmodule PresenceChat.Chat.Message do
  @moduledoc """
  Pure, side-effect-free logic for chat messages and display names.

  Kept deliberately free of any LiveView/Presence/PubSub concerns so it can
  be unit tested in isolation with plain ExUnit -- no socket, no process,
  no broadcast required. `PresenceChatWeb.RoomLive` is the only caller.
  """

  @max_body_length 500
  @max_name_length 30

  @doc """
  Validates and normalizes a chat message body.

  Returns `{:ok, body}` with leading/trailing whitespace trimmed and
  internal whitespace runs collapsed, or `{:error, reason}` if the body is
  blank or exceeds #{@max_body_length} characters.

  ## Examples

      iex> PresenceChat.Chat.Message.validate_body("  hello   world  ")
      {:ok, "hello world"}

      iex> PresenceChat.Chat.Message.validate_body("   ")
      {:error, :blank}

      iex> PresenceChat.Chat.Message.validate_body(String.duplicate("a", 501))
      {:error, :too_long}
  """
  @spec validate_body(String.t()) :: {:ok, String.t()} | {:error, :blank | :too_long}
  def validate_body(body) when is_binary(body) do
    trimmed = sanitize(body)

    cond do
      trimmed == "" -> {:error, :blank}
      String.length(trimmed) > @max_body_length -> {:error, :too_long}
      true -> {:ok, trimmed}
    end
  end

  @doc """
  Strips control characters and collapses runs of whitespace down to a
  single space, then trims the ends. This is defense-in-depth cleanup of
  the raw string -- HTML escaping itself is handled separately by HEEx's
  automatic escaping when the message is rendered, so this function never
  needs to (and must not) produce HTML.

  ## Examples

      iex> PresenceChat.Chat.Message.sanitize("hi\\tthere\\n\\nfriend")
      "hi there friend"

      iex> PresenceChat.Chat.Message.sanitize("<script>alert(1)</script>")
      "<script>alert(1)</script>"
  """
  @spec sanitize(String.t()) :: String.t()
  def sanitize(body) when is_binary(body) do
    body
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F]/u, "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  @doc """
  Normalizes a user-supplied display name: trims it, collapses whitespace,
  truncates to #{@max_name_length} characters, and falls back to
  `"Anonymous"` when blank.

  ## Examples

      iex> PresenceChat.Chat.Message.format_display_name("  Ada   Lovelace ")
      "Ada Lovelace"

      iex> PresenceChat.Chat.Message.format_display_name("")
      "Anonymous"

      iex> PresenceChat.Chat.Message.format_display_name(nil)
      "Anonymous"
  """
  @spec format_display_name(String.t() | nil) :: String.t()
  def format_display_name(nil), do: "Anonymous"

  def format_display_name(name) when is_binary(name) do
    case sanitize(name) do
      "" -> "Anonymous"
      trimmed -> String.slice(trimmed, 0, @max_name_length)
    end
  end
end
