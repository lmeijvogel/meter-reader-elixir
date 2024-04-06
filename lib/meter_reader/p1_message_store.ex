defmodule MeterReader.P1MessageStore do
  use Agent

  def start_link(:ok) do
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  def get() do
    Agent.get(__MODULE__, & &1)
  end

  def set(message) do
    Agent.update(__MODULE__, fn _ -> message end)
  end
end
