defmodule MeterReader.PostgresTempSupervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(test_mode) do
    children = [
      {Backends.Postgres.TempBackend, Application.get_env(:meter_reader, :postgres_temp)},
      {Backends.Postgres.TempDispatcher,
       save_interval_in_seconds:
         Application.get_env(:meter_reader, :postgres_save_interval_in_seconds),
       start: !test_mode}
    ]

    Supervisor.init(children, strategy: :one_for_one, name: __MODULE__)
  end
end
