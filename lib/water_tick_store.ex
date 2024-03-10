defmodule MeterReader.WaterTickStore do
  use GenServer

  def init(opts) do
    if opts[:get_start_data] do
      Process.send_after(__MODULE__, :init_last_measurement, 0)
    end

    {:ok, %{water: 0}}
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
    {:noreply, %{state | water: state[:water] + 1}}
  end

  def handle_info(:init_last_measurement, state) do
    query = "SELECT water FROM measurements ORDER BY id DESC LIMIT 1"

    {:ok, %MyXQL.Result{rows: [row]}} = MyXQL.query(:myxql, query)

    {:noreply, %{state | water: Enum.at(row, 0)}}
  end
end
