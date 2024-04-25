defmodule Backends.Mysql.Dispatcher do
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
  For SQL, the current water "tick" is retrieved and is sent along with the P1 data.
  """

  @impl true
  def init(opts) do
    state = %{
      save_interval_in_seconds: opts[:save_interval_in_seconds]
    }

    if opts[:start] do
      schedule_next_mysql_save(state)
    end

    {:ok, state}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def handle_info(:save_to_mysql, state) do
    schedule_next_mysql_save(state)

    with_last_p1_message(fn message ->
      water_ticks = MeterReader.WaterTickStore.get()

      Logger.info("Mysql.Dispatcher: Sending P1 message to MySQL")
      Backends.Mysql.Backend.save(message, water_ticks)
    end)

    {:noreply, state}
  end

  def with_last_p1_message(callback) do
    message = MeterReader.P1MessageStore.get()

    if message != nil do
      callback.(message)
    else
      Logger.warning("Mysql.Dispatcher: No P1 message in store")
    end
  end

  def schedule_next_mysql_save(state) do
    Scheduler.schedule_next(
      {self(), :save_to_mysql},
      "Mysql.Dispatcher",
      {state[:save_interval_in_seconds]}
    )
  end
end
