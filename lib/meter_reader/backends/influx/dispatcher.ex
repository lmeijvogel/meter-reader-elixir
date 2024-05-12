defmodule Backends.Influx.Dispatcher do
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

  For Influx, only the P1 data is stored -- Water data is already in Influx.
  """

  @impl true
  def init(opts) do
    state = %{
      save_interval_in_seconds: opts[:save_interval_in_seconds]
    }

    if opts[:start] do
      schedule_next_influx_save(state)
    end

    {:ok, state}
  end

  def p1_message_received(message) do
    GenServer.cast(__MODULE__, {:p1_message_received, message})
  end

  def water_tick_received do
    Logger.debug("Influx.Dispatcher: Storing water tick in InfluxDB")

    Backends.Influx.Backend.store_water_tick()
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def handle_cast({:p1_message_received, message}, state) do
    Backends.Influx.Backend.store_temporary_p1(message)

    {:noreply, state}
  end

  @impl true
  def handle_info(:save_to_influx, state) do
    schedule_next_influx_save(state)

    MeterReader.P1MessageStore.with_latest_message(
      &Backends.Influx.Backend.store_p1/1,
      fn -> Logger.warning("Influx.Dispatcher: No P1 message in store") end
    )

    {:noreply, state}
  end

  def schedule_next_influx_save(state) do
    MeterReader.Scheduler.schedule_next(
      {self(), :save_to_influx},
      "Influx.Dispatcher",
      {state[:save_interval_in_seconds]}
    )
  end
end
