defmodule MeterReader.WaterTickStore do
  require Logger
  use GenServer

  def init(opts) do
    if opts[:get_start_data] do
      {:ok, %{water: nil}, {:continue, :init_last_measurement}}
    else
      {:ok, %{water: 0}}
    end
  end

  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def increment do
    GenServer.cast(__MODULE__, :increment)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def handle_call(:get, _from, state) do
    {:reply, state[:water], state}
  end

  def handle_cast(:increment, state) do
    Logger.debug("WaterTickStore: Incrementing #{state[:water]} => #{state[:water] + 1}")
    {:noreply, %{state | water: state[:water] + 1}}
  end

  def handle_continue(:init_last_measurement, state) do
    Logger.debug("WaterTickStore :init_last_measurement")

    query = "SELECT water FROM measurements ORDER BY id DESC LIMIT 1"

    {:ok, %MyXQL.Result{rows: [row]}} = MyXQL.query(:myxql, query)

    value = Enum.at(row, 0)

    Logger.debug("WaterTickStore: got value #{value}")

    {:noreply, %{state | water: value}}
  end
end
