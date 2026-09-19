import Config

# For development, we disable any cache and enable debugging and code
# reloading.
config :presence_chat, PresenceChatWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "5S6qk1M2y3W0k8N7z1cQdE9pXrT4vB6nH2jL8sA0fG3iU7oY5wZ1xC4mR9tK6qP2",
  watchers: []

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true
