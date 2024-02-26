defmodule MeterReader.Ticker do
  use GenServer

  # NO LONGER USED
  @impl true
  def init(:ok) do
    Process.send_after(self(), :tick, 1000)

    {:ok, %{}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def handle_info(:tick, _) do
    # IO.puts(MeterReader.MeterReader.value())

    {:noreply, %{}}
  end
end
