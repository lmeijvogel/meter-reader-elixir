defmodule Backends.InfluxTemporaryDataConnection do
  use Instream.Connection, otp_app: :meter_reader
end
