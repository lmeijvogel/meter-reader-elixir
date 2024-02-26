import Config

config :meter_reader,
  p1_port: "/dev/pts/2",
  p1_speed: 115_200,
  p1_data_bits: 7,
  p1_stop_bits: 1,
  p1_parity: :even
