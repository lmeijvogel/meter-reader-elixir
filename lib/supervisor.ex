defmodule MeterReader.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {MeterReader.MeterReader, %{port: Application.get_env(:meter_reader, :p1_port)}},
      MeterReader.P1Store
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
