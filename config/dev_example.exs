import Config

config :meter_reader,
  solar_edge_api_key: "12345",
  solar_edge_site_id: "12345",
  # Backends
  db_hostname: "127.0.0.1",
  db_database: "meter_reader",
  db_username: "root",
  # db_password: nil
  db_save_interval_in_seconds: 1,
  redis_measurements_list_name: "latest_measurements",
  redis_host: "localhost"

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
  parity: :even

config :meter_reader, :solar_edge,
  host: "http://127.0.0.1:8080/"
  site_id: "12345",
  api_key: "abcdefg"

shared_influx_config = [
  auth: [
    method: :token,
    token: "<FILL IN YOUR TOKEN HERE>"
  ],
  org: "home",
  # Statically configured on VM
  host: "192.168.56.8",
  version: :v2
]

config :meter_reader, Backends.InfluxConnection, shared_influx_config ++ [bucket: "readings"]

config :meter_reader,
       Backends.InfluxTemporaryDataConnection,
       shared_influx_config ++ [bucket: "readings_last_hour"]
