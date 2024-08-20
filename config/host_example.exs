# This is an example file. Copy to `host.exs` and fill in relevant credentials

import Config

# Add configuration that is only needed when running on the host here.

config :nerves_runtime,
  kv_backend:
    {Nerves.Runtime.KVBackend.InMemory,
     contents: %{
       # The KV store on Nerves systems is typically read from UBoot-env, but
       # this allows us to use a pre-populated InMemory store when running on
       # host for development and testing.
       #
       # https://hexdocs.pm/nerves_runtime/readme.html#using-nerves_runtime-in-tests
       # https://hexdocs.pm/nerves_runtime/readme.html#nerves-system-and-firmware-metadata

       "nerves_fw_active" => "a",
       "a.nerves_fw_architecture" => "generic",
       "a.nerves_fw_description" => "N/A",
       "a.nerves_fw_platform" => "host",
       "a.nerves_fw_version" => "0.0.0"
     }}

config :meter_reader,
  # Backends
  redis_measurements_list_name: "latest_measurements",
  redis_host: "localhost",
  db_save_interval_in_seconds: 8,

config :meter_reader, :sql,
  hostname: "127.0.0.1",
  database: "meter_reader",
  username: "root"

# password: nil

config :meter_reader, :water_meter,
  port: "/tmp/water_output",
  speed: 115_200,
  data_bits: 7,
  stop_bits: 1,
  parity: :even

config :meter_reader, :p1_reader,
  port: "/tmp/p1_output",
  speed: 115_200,
  data_bits: 7,
  stop_bits: 1,
  parity: :even,
  message_start_marker: "/ABCDEFGHI-METER"

config :meter_reader, :solar_edge,
  start: true,
  start_hour: 7,
  end_hour: 22,
  interval_in_seconds: 10,
  interval_offset_in_seconds: 0,
  host: "http://127.0.0.1:4567",
  site_id: "12345",
  api_key: "THISISANAPIKEY"
