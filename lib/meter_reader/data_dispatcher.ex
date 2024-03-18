defmodule MeterReader.DataDispatcher do
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

  def init(opts) do
    state = %{
      db_save_interval_in_seconds: opts[:db_save_interval_in_seconds],
      influx_save_interval_in_seconds: opts[:influx_save_interval_in_seconds]
    }

    if opts[:start] do
      schedule_next_sql_save(state)
      schedule_next_influx_save(state)
    end

    {:ok, state}
  end

  def p1_message_received(message) do
    GenServer.cast(__MODULE__, {:p1_message_received, message})
  end

  def water_tick_received do
    Backends.InfluxBackend.store_water_tick()
    MeterReader.WaterTickStore.increment()
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def handle_cast({:p1_message_received, message}, state) do
    if valid?(message, state[:last_message]) do
      new_state = Map.put(state, :last_p1_message, message)

      Backends.InfluxBackend.store_temporary_p1(message)

      {:noreply, new_state}
    else
      Logger.warning("Dropping invalid message")

      {:noreply, state}
    end
  end

  def handle_info(:save_to_sql, state) do
    schedule_next_sql_save(state)

    if Map.has_key?(state, :last_p1_message) do
      water_ticks = MeterReader.WaterTickStore.get()

      last_p1_message = Map.get(state, :last_p1_message)
      Backends.SqlBackend.save(last_p1_message, water_ticks)
    else
      Logger.warning("Scheduled saving P1 message to SQL, but no message in store")
    end

    {:noreply, state}
  end

  def handle_info(:save_to_influx, state) do
    schedule_next_influx_save(state)

    if Map.has_key?(state, :last_p1_message) do
      Logger.info("Sending P1 message to InfluxDB")
      Backends.InfluxBackend.store_p1(Map.get(state, :last_p1_message))
    else
      Logger.warning("Scheduled saving P1 message to InfluxDB, but no message in store")
    end

    {:noreply, state}
  end

  # Sometimes the measurements are invalid, e.g. a measurement is missing
  # or is lower than the last measurement. In that case drop the message.
  def valid?(message, last_message) do
    cond do
      last_message == nil -> true
      message[:stroom_piek] < last_message[:stroom_piek] -> false
      message[:stroom_dal] < last_message[:stroom_dal] -> false
      message[:levering_piek] < last_message[:levering_piek] -> false
      message[:levering_dal] < last_message[:levering_dal] -> false
      message[:gas] < last_message[:gas] -> false
      true -> true
    end
  end

  def schedule_next_sql_save(state) do
    time_until_save =
      MeterReader.IntervalCalculator.seconds_to_next(
        Time.utc_now(),
        state[:db_save_interval_in_seconds]
      )

    Process.send_after(__MODULE__, :save_to_sql, time_until_save * 1000)
  end

  def schedule_next_influx_save(state) do
    time_until_save =
      MeterReader.IntervalCalculator.seconds_to_next(
        Time.utc_now(),
        state[:influx_save_interval_in_seconds]
      )

    Process.send_after(__MODULE__, :save_to_influx, time_until_save * 1000)
  end
end
