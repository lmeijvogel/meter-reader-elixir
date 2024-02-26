defmodule MessageParser do
  use GenServer

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end

  @impl true
  def handle_cast({:test}, state) do
    IO.puts("TEST")

    {:noreply, state}
  end
end
