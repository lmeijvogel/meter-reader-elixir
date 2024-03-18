defmodule Backends.InfluxConnection do
  use Instream.Connection, otp_app: :meter_reader
end
