import Config

{secrets, _binding} = Code.eval_file("config/target_secrets.exs")

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

config :logger, backends: [RingLogger]

# Enable a file backend for the ring logger
# config :logger, RingLogger, persist_path: "/data/meter-reader.log", persist_seconds: 300

# Use shoehorn to start the main application. See the shoehorn
# library documentation for more control in ordering how OTP
# applications are started and handling failures.

config :shoehorn, init: [:nerves_runtime, :nerves_pack]

# Erlinit can be configured without a rootfs_overlay. See
# https://github.com/nerves-project/erlinit/ for more information on
# configuring erlinit.

# Advance the system clock on devices without real-time clocks.
config :nerves, :erlinit, update_clock: true

# Write tzdata data to a writeable directory
config :tzdata, :data_dir, "/root/elixir_tzdata_data"

# Configure the device for SSH IEx prompt access and firmware updates
#
# * See https://hexdocs.pm/nerves_ssh/readme.html for general SSH configuration
# * See https://hexdocs.pm/ssh_subsystem_fwup/readme.html for firmware updates

keys =
  [
    Path.join([System.user_home!(), ".ssh", "id_rsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ecdsa.pub"]),
    Path.join([System.user_home!(), ".ssh", "id_ed25519.pub"])
  ]
  |> Enum.filter(&File.exists?/1)

if keys == [],
  do:
    Mix.raise("""
    No SSH public keys found in ~/.ssh. An ssh authorized key is needed to
    log into the Nerves device and update firmware on it using ssh.
    See your project's config.exs for this error message.
    """)

config :nerves_ssh,
  authorized_keys: Enum.map(keys, &File.read!/1)

# Configure the network using vintage_net
#
# Update regulatory_domain to your 2-letter country code E.g., "US"
#
# See https://github.com/nerves-networking/vintage_net for more information
config :vintage_net,
  regulatory_domain: "00",
  config: [
    {"usb0", %{type: VintageNetDirect}},
    {"eth0",
     %{
       type: VintageNetEthernet,
       ipv4: %{
         method: :static,
         address: "192.168.2.2",
         prefix_length: 24,
         gateway: "192.168.2.254",
         name_servers: ["192.168.2.254"]
       }
     }},
    {"wlan0", %{type: VintageNetWiFi}}
  ]

config :mdns_lite,
  # The `hosts` key specifies what hostnames mdns_lite advertises.  `:hostname`
  # advertises the device's hostname.local. For the official Nerves systems, this
  # is "nerves-<4 digit serial#>.local".  The `"nerves"` host causes mdns_lite
  # to advertise "nerves.local" for convenience. If more than one Nerves device
  # is on the network, it is recommended to delete "nerves" from the list
  # because otherwise any of the devices may respond to nerves.local leading to
  # unpredictable behavior.

  hosts: [:hostname, "meter_reader"],
  ttl: 120,

  # Advertise the following services over mDNS.
  services: [
    %{
      protocol: "ssh",
      transport: "tcp",
      port: 22
    },
    %{
      protocol: "sftp-ssh",
      transport: "tcp",
      port: 22
    },
    %{
      protocol: "epmd",
      transport: "tcp",
      port: 4369
    }
  ]

config :meter_reader,
  # Backends
  db_save_interval_in_seconds: 600,
  postgres_save_interval_in_seconds: 60,
  influx_save_interval_in_seconds: 60

config :meter_reader, :redis,
  host: secrets.redis_host,
  redis_current_latest_measurements_list_name: "latest_current_measurements",
  redis_water_last_ticks_list_name: "water_meter_last_ticks"

config :meter_reader, :sql,
  hostname: secrets.mysql_hostname,
  database: secrets.mysql_database,
  username: secrets.mysql_username,
  password: secrets.mysql_password

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
  port: "/dev/ttyACM0",
  speed: 9600,
  data_bits: 8,
  parity: :none,
  stop_bits: 1

config :meter_reader, :p1_reader,
  port: "/dev/ttyUSB0",
  speed: 115_200,
  data_bits: 7,
  parity: :even,
  stop_bits: 1,
  message_start_marker: secrets.p1_message_start_marker

# LED_BRIGHTNESS_PATH: "/sys/class/leds/led0/brightness"
# LED_TRIGGER_PATH: "/sys/class/leds/led0/trigger"

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
  start: true,
  start_hour: 7,
  end_hour: 22,
  interval_in_seconds: 900,
  interval_offset_in_seconds: 180,
  host: "https://monitoringapi.solaredge.com",
  site_id: secrets.solaredge_site_id,
  api_key: secrets.solaredge_api_key

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.target()}.exs"
