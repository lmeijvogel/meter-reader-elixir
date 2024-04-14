defmodule MeterReader.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {MyXQL, myqxl_config()},
      {MeterReader.WaterTickStore, get_start_data: !test_mode()},
      {MeterReader.P1MessageStore, :ok},
      Backends.SqlBackend,
      {MeterReader.SqlDispatcher,
       save_interval_in_seconds: Application.get_env(:meter_reader, :db_save_interval_in_seconds),
       start: !test_mode()},
      Backends.InfluxConnection,
      Backends.InfluxTemporaryDataConnection,
      Backends.InfluxBackend,
      {MeterReader.InfluxDispatcher,
       save_interval_in_seconds:
         Application.get_env(:meter_reader, :influx_save_interval_in_seconds),
       start: !test_mode()},
      {Backends.PostgresBackend, Application.get_env(:meter_reader, :postgres)},
      {MeterReader.PostgresDispatcher,
       save_interval_in_seconds:
         Application.get_env(:meter_reader, :postgres_save_interval_in_seconds),
       start: !test_mode()},
      {MeterReader.WaterReader, water_reader_config()},
      {MeterReader.P1Reader, p1_reader_config()},
      {MeterReader.SolarEdgeReader, Application.get_env(:meter_reader, :solar_edge)}
    ]

    Supervisor.init(children, strategy: :one_for_one, name: MeterReader.Supervisor)
  end

  def myqxl_config do
    Application.get_env(:meter_reader, :sql) ++
      [
        name: :myxql
      ]
  end

  def water_reader_config do
    [start: !test_mode()] ++ Application.get_env(:meter_reader, :water_meter)
  end

  def p1_reader_config do
    [start: !test_mode()] ++ Application.get_env(:meter_reader, :p1_reader)
  end

  def test_mode do
    Application.get_env(:meter_reader, :test_mode)
  end
end
