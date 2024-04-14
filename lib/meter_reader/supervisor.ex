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
      {MeterReader.InfluxSupervisor, test_mode()},
      {MeterReader.MysqlSupervisor, test_mode()},
      {MeterReader.PostgresSupervisor, test_mode()},
      {MeterReader.WaterReader, water_reader_config()},
      {MeterReader.P1Reader, p1_reader_config()},
      {MeterReader.SolarEdgeReader, Application.get_env(:meter_reader, :solar_edge)}
    ]

    Supervisor.init(children, strategy: :rest_for_one, name: MeterReader.Supervisor)
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
