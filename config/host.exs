import Config

{secrets, _binding} = Code.eval_file("config/host_secrets.exs")

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
  db_save_interval_in_seconds: 8,
  postgres_save_interval_in_seconds: 8,
  influx_save_interval_in_seconds: 3

config :meter_reader, :sql,
  hostname: secrets.mysql_hostname,
  database: secrets.mysql_database,
  username: secrets.mysql_username,
  password: secrets.mysql_password

config :meter_reader, :redis,
  host: secrets.redis_host,
  redis_current_last_measurement_name: "last_current_measurement",
  redis_current_recent_measurements_list_name: "recent_current_measurements",
  redis_water_last_ticks_list_name: "water_meter_last_ticks"

config :meter_reader, :postgres,
  hostname: secrets.postgres_hostname,
  database: secrets.postgres_database,
  username: secrets.postgres_username,
  password: secrets.postgres_password

config :meter_reader, :postgres_temp,
  hostname: secrets.postgres_hostname,
  database: secrets.postgres_database_temp,
  username: secrets.postgres_username,
  password: secrets.postgres_password

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
  message_start_marker: secrets.p1_message_start_marker

shared_influx_config = [
  auth: [
    method: :token,
    token: secrets.influx_token
  ],
  org: secrets.influx_org,
  # Statically configured on VM
  host: secrets.influx_hostname,
  version: :v2
]

config :meter_reader,
       Backends.Influx.Connection,
       shared_influx_config ++ [bucket: "readings"]

config :meter_reader,
       Backends.Influx.TemporaryDataConnection,
       shared_influx_config ++ [bucket: "readings_last_hour"]

config :meter_reader, :solar_edge,
  start_hour: 7,
  end_hour: 23,
  interval_in_seconds: 10,
  interval_offset_in_seconds: 0,
  host: "http://127.0.0.1:4567",
  site_id: secrets.solaredge_site_id,
  api_key: secrets.solaredge_api_key

config :meter_reader, :home_assistant,
  interval_in_seconds: 10,
  host: secrets.homeassistant_host,
  api_key: secrets.homeassistant_api_key
