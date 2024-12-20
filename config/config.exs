# This file is responsible for configuring your application and its
# dependencies.
#
# This configuration file is loaded before any dependency and is restricted to
# this project.
import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :nerves_time, await_initialization_timeout: :timer.seconds(5)

# Enable the Nerves integration with Mix
Application.start(:nerves_bootstrap)

config :meter_reader, target: Mix.target()

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1710624364"

config :meter_reader, :home_assistant,
  sensors: %{
    motionsensor_air_temperature: "huiskamer",
    motionsensor_tuinkamer_air_temperature: "tuinkamer",
    motionsensor_zolder_air_temperature: "zolder"
  }

if Mix.target() == :host do
  import_config "host.exs"
else
  import_config "target.exs"
end
