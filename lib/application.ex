defmodule MeterReader.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [MeterReader.Supervisor]
    opts = [strategy: :one_for_one, name: MeterReader.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
