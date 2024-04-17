defmodule Backends.Postgres.ProdEnabledStore do
  use Agent

  @moduledoc """
  Stores whether the postgres backend is enabled, to ensure that it doesn't get reset
  if something goes wrong in the backend.
  """

  def start_link(state) do
    Agent.start_link(fn -> state end, name: __MODULE__)
  end

  def enabled?() do
    Agent.get(__MODULE__, & &1)
  end

  def enable() do
    Agent.update(__MODULE__, fn _ -> true end)
  end

  def disable() do
    Agent.update(__MODULE__, fn _ -> false end)
  end
end
