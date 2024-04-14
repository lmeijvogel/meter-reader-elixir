defmodule MeterReader.InfluxSupervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(test_mode) do
    children = [
      Backends.Influx.Connection,
      Backends.Influx.TemporaryDataConnection,
      Backends.Influx.Backend,
      {Backends.Influx.Dispatcher,
       save_interval_in_seconds:
         Application.get_env(:meter_reader, :influx_save_interval_in_seconds),
       start: !test_mode}
    ]

    Supervisor.init(children, strategy: :rest_for_one, name: __MODULE__)
  end
end
