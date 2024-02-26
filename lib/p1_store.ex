defmodule MeterReader.P1Store do
  use GenServer

  def init(_) do
    {:ok, %{}}
  end

  def message_received(message) do
    GenServer.cast(__MODULE__, {:message_received, message})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def handle_cast({:message_received, message}, state) do
    IO.puts("Received!")
    IO.puts(inspect(message))

    {:noreply, state}
  end
end
