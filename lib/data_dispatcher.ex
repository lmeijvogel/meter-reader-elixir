defmodule MeterReader.DataDispatcher do
  use GenServer

  def init(opts) do
    state = %{db_save_interval_in_seconds: opts[:db_save_interval_in_seconds]}

    # TODO: I don't really like this approach. Since we're receiving messages every 1s anyway
    # why not use the current time and the previous save time to determine whether we should write
    # to the database / influx
    if opts[:start] do
      schedule_next_save(state)
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

      # TODO: Do not write all data every second?
      save_p1_to_influx(message)

      {:noreply, new_state}
    else
      IO.warn("Dropping invalid message")

      {:noreply, state}
    end
  end

  def handle_info(:save_to_sql, state) do
    schedule_next_save(state)

    if Map.has_key?(state, :last_p1_message) do
      Backends.SqlBackend.save(Map.get(state, :last_p1_message))
    end

    {:noreply, Map.delete(state, :last_p1_message)}
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

  def save_p1_to_influx(message) do
    Backends.InfluxBackend.store_p1(message)
  end

  def schedule_next_save(state) do
    time_until_save =
      MeterReader.IntervalCalculator.seconds_to_next(
        Time.utc_now(),
        state[:db_save_interval_in_seconds]
      )

    Process.send_after(__MODULE__, :save_to_sql, time_until_save * 1000)
  end
end
