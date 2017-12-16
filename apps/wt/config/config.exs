# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :t405s1new, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:t405s1new, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
#config :maru, API,
#  http: [port: 8800]


config :elastex, url: "31.13.250.31:9200", key: "!!!###5R6T7Y"

config :wt,
  port: "ttyO4",
  speed: 9600,
  timer: 400

config :wt, :rabbitmq_settings,
  host: "31.13.249.123",
  port: 5672,
  virtual_host: "/watchtok",
  username: "watchtok",
  password: "watchtok"

config :wt, amqp_exchange:    <<"watchtok_ex">>
config :wt, amqp_routing_key: <<"dev.embedded_green">>
config :wt, amqp_queue:       <<"test2">>
config :wt, amqp_queue_subscribe?: :false
