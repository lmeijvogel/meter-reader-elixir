defmodule Backends.Influx.TemporaryDataConnection do
  use Instream.Connection, otp_app: :meter_reader
end
