defmodule MeterReader.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    is_prod = !test_mode?()

    children = [
      {MyXQL, myqxl_config()},
      {Redix, redix_config()},
      {MeterReader.WaterTickStore, get_start_data: is_prod},
      {MeterReader.P1MessageStore, :ok},
      {Backends.RedisBackend, Application.get_env(:meter_reader, :redis)},
      {MeterReader.MysqlSupervisor, test_mode?()},
      {MeterReader.PostgresSupervisor, test_mode?()},
      {MeterReader.WaterReader, water_reader_config()},
      {MeterReader.P1MessageDecoder, p1_reader_config()[:message_start_marker]},
      {MeterReader.P1Reader, p1_reader_config()},
      {MeterReader.SolarEdgeReader,
       Application.get_env(:meter_reader, :solar_edge) ++ [start: is_prod]},
      {MeterReader.HomeAssistantReader,
       Application.get_env(:meter_reader, :home_assistant) ++ [start: is_prod]}
    ]

    Supervisor.init(children,
      strategy: :rest_for_one,
      name: MeterReader.Supervisor,
      max_restarts: 99,
      max_seconds: 10
    )
  end

  def myqxl_config do
    Application.get_env(:meter_reader, :sql) ++
      [
        name: :myxql
      ]
  end

  def redix_config do
    [
      host: Application.get_env(:meter_reader, :redis)[:host],
      name: :redix
    ]
  end

  def water_reader_config do
    [start: !test_mode?()] ++ Application.get_env(:meter_reader, :water_meter)
  end

  def p1_reader_config do
    [start: !test_mode?()] ++ Application.get_env(:meter_reader, :p1_reader)
  end

  def test_mode? do
    # In production, Mix is not included, so return false in that case
    function_exported?(Mix, :env, 0) && Mix.env() == :test
  end
end
