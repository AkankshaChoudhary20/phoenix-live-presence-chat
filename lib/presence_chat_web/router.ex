defmodule PresenceChatWeb.Router do
  use PresenceChatWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PresenceChatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", PresenceChatWeb do
    pipe_through :browser

    live "/", RoomLive, :index
    live "/rooms/:room_id", RoomLive, :index
  end
end
