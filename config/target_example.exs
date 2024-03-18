# Example file. Rename this to `target.exs` and fill the relevant credentials
import Config

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

config :logger, backends: [RingLogger]

# Use shoehorn to start the main application. See the shoehorn
# library documentation for more control in ordering how OTP
# applications are started and handling failures.

config :shoehorn, init: [:nerves_runtime, :nerves_pack]

# Erlinit can be configured without a rootfs_overlay. See
# https://github.com/nerves-project/erlinit/ for more information on
# configuring erlinit.

# Advance the system clock on devices without real-time clocks.
config :nerves, :erlinit, update_clock: true

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
         address: "<ip address>",
         prefix_length: 24,
         gateway: "<gateway>",
         name_servers: ["<gateway>"]
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
  redis_measurements_list_name: "latest_measurements",
  redis_host: "localhost",
  db_save_interval_in_seconds: 600,
  influx_save_interval_in_seconds: 1

config :meter_reader, :sql,
  hostname: "<hostname>",
  database: "<database>",
  username: "<username>",
  password: "<password>"

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
  message_start_marker: "/ABCDEFGHI-METER"

shared_influx_config = [
  auth: [
    method: :token,
    token: "<token>"
  ],
  org: "home",
  # Statically configured on VM
  host: "<host>",
  version: :v2
]

config :meter_reader, Backends.InfluxConnection, shared_influx_config ++ [bucket: "readings"]

config :meter_reader,
       Backends.InfluxTemporaryDataConnection,
       shared_influx_config ++ [bucket: "readings_last_hour"]

config :meter_reader, :solar_edge,
  start: true,
  start_hour: 7,
  end_hour: 22,
  interval_in_seconds: 900,
  interval_offset_in_seconds: 180,
  host: "https://monitoringapi.solaredge.com",
  site_id: "<site id>",
  api_key: "<api key>"

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.target()}.exs"
