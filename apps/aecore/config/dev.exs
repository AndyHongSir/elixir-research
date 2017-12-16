# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :aecore, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:aecore, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
config :aecore, :persistence,
  table: Path.absname("apps/aecore/priv/persistence_table")

config :aecore, :pow,
  nif_path: Path.absname("apps/aecore/priv/aec_pow_cuckoo20_nif"),
  genesis_header: %{
    height: 0,
    prev_hash: <<0::256>>,
    txs_hash: <<0::256>>,
    chain_state_hash: <<0 :: 256>>,
    timestamp: 1_507_275_094_308,
    nonce: 200,
    pow_evidence: [3648, 8843, 21543, 26898, 27911, 80481, 90869, 94920, 111409,
                   141502, 158871, 163838, 188849, 204702, 211458, 228575, 251612, 259287,
                   263340, 284433, 291846, 295291, 297685, 299482, 319474, 322942, 328920,
                   338016, 340252, 361960, 372181, 378872, 379566, 384041, 386304, 413039,
                   416760, 423217, 459712, 495538, 500437, 505710],
    version: 1,
    difficulty_target: 1
  }
