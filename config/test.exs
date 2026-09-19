import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :presence_chat, PresenceChatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6bYq8kM1wZ0lJ9vN2sC5xD7eR3tU8oI4pA6gH1fK9jL2mQ0wE5rT7yB3nS8cV1xZ",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view, enable_expensive_runtime_checks: true
