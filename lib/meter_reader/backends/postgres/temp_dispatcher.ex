defmodule Backends.Postgres.TempDispatcher do
  require Logger
  use GenServer

  @moduledoc """
  This module is responsible for receiving all data that is sent to us - Water and P1 energy - and
  sending it to the various backends.

  SolarEdge data does not go through this module.

  When a water tick is received, it is immediately sent to InfluxDB. When the
  current P1 readings are received, the message is kept in state and the
  current energy usage/generation is sent to a temporary InfluxDB backend that
  deletes older data.

  The permanent data is stored at intervals to not fill up the data stores too quickly.

  To do this, it keeps the latest P1 message -- its data is cumulative. The latest message
  is then sent to the backends.
  """

  def init(opts) do
    state = %{
      save_interval_in_seconds: opts[:save_interval_in_seconds]
    }

    if opts[:start] do
      schedule_next_postgres_save(state)
    end

    {:ok, state}
  end

  def water_tick_received do
    Backends.Postgres.TempBackend.store_water()
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def handle_info(:save_to_postgres, state) do
    schedule_next_postgres_save(state)

    MeterReader.P1MessageStore.with_latest_message(
      &Backends.Postgres.TempBackend.store_p1/1,
      fn -> Logger.warning("Postgres.TempDispatcher: No P1 message in store") end
    )

    {:noreply, state}
  end

  defp schedule_next_postgres_save(state) do
    Scheduler.schedule_next(
      {self(), :save_to_postgres},
      "Postgres.TempDispatcher",
      {state[:save_interval_in_seconds]}
    )
  end
end
