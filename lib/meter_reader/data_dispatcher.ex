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
      postgres_save_interval_in_seconds: opts[:postgres_save_interval_in_seconds],
      influx_save_interval_in_seconds: opts[:influx_save_interval_in_seconds]
    }

    if opts[:start] do
      schedule_next_mysql_save(state)
      schedule_next_postgres_save(state)
      schedule_next_influx_save(state)
    end

    {:ok, state}
  end

  def p1_message_received(message) do
    GenServer.cast(__MODULE__, {:p1_message_received, message})
  end

  def water_tick_received do
    Backends.InfluxBackend.store_water_tick()
    Backends.PostgresBackend.store_water()
    MeterReader.WaterTickStore.increment()
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def handle_cast({:p1_message_received, message}, state) do
    Backends.InfluxBackend.store_temporary_p1(message)

    {:noreply, state}
  end

  def handle_info(:save_to_mysql, state) do
    schedule_next_mysql_save(state)

    last_p1_message = MeterReader.P1MessageStore.get()

    if last_p1_message != nil do
      water_ticks = MeterReader.WaterTickStore.get()

      Backends.SqlBackend.save(last_p1_message, water_ticks)
    else
      Logger.warning("Scheduled saving P1 message to SQL, but no message in store")
    end

    {:noreply, state}
  end

  def handle_info(:save_to_influx, state) do
    schedule_next_influx_save(state)

    last_p1_message = MeterReader.P1MessageStore.get()

    if last_p1_message != nil do
      Logger.info("Sending P1 message to InfluxDB")
      Backends.InfluxBackend.store_p1(last_p1_message)
    else
      Logger.warning("Scheduled saving P1 message to InfluxDB, but no message in store")
    end

    {:noreply, state}
  end

  def handle_info(:save_to_postgres, state) do
    schedule_next_postgres_save(state)
    last_p1_message = MeterReader.P1MessageStore.get()

    if last_p1_message != nil do
      Logger.info("Sending P1 message to Postgres")
      Backends.PostgresBackend.store_p1(last_p1_message)
    else
      Logger.warning("Scheduled saving P1 message to Postgres, but no message in store")
    end

    {:noreply, state}
  end

  def schedule_next_mysql_save(state) do
    time_until_save =
      MeterReader.IntervalCalculator.seconds_to_next(
        Time.utc_now(),
        state[:db_save_interval_in_seconds]
      )

    Process.send_after(__MODULE__, :save_to_mysql, time_until_save * 1000)
    Logger.info("Scheduling next MySQL store interval: #{time_until_save}s")
  end

  def schedule_next_influx_save(state) do
    time_until_save =
      MeterReader.IntervalCalculator.seconds_to_next(
        Time.utc_now(),
        state[:influx_save_interval_in_seconds]
      )

    Process.send_after(__MODULE__, :save_to_influx, time_until_save * 1000)
    Logger.info("Scheduling next InfluxDB store interval: #{time_until_save}s")
  end

  def schedule_next_postgres_save(state) do
    time_until_save =
      MeterReader.IntervalCalculator.seconds_to_next(
        Time.utc_now(),
        state[:postgres_save_interval_in_seconds]
      )

    Process.send_after(__MODULE__, :save_to_postgres, time_until_save * 1000)
    Logger.info("Scheduling next postgres store interval: #{time_until_save}s")
  end
end
