defmodule Backends.RedisBackend do
  require Logger

  use GenServer

  @seconds_between_power_reports 5
  @seconds_of_reports_to_store 7200
  @number_of_current_entries div(@seconds_of_reports_to_store, @seconds_between_power_reports)

  @impl true
  def init(config) do
    state = %{
      redis_current_recent_measurements_list_name:
        config[:redis_current_recent_measurements_list_name],
      redis_current_last_measurement_name: config[:redis_current_last_measurement_name],
      redis_water_last_ticks_list_name: config[:redis_water_last_ticks_list_name],
      last_stored_timestamp: DateTime.utc_now()
    }

    {:ok, state}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def p1_message_received(message) do
    GenServer.cast(__MODULE__, {:p1_message_received, message})
  end

  def store_water_tick do
    GenServer.cast(__MODULE__, :store_water_tick)
  end

  @impl true
  def handle_cast({:p1_message_received, message}, state) do
    if message == nil do
      {:noreply, state}
    else
      power = message.stroom_current - message.levering_current

      # Always store the last power measurement
      Redix.command(:redix, ["SET", state.redis_current_last_measurement_name, power])

      last_stored_timestamp = state.last_stored_timestamp
      seconds_since_last = DateTime.diff(message.timestamp, last_stored_timestamp)

      # Store last hours of data once every 5 seconds until I know the memory usage
      if seconds_since_last < @seconds_between_power_reports do
        {:noreply, state}
      else
        Logger.debug("Backends.RedisBackend: Storing temporary power usage")

        data_for_redis = %{
          timestamp: message.timestamp,
          power: round(power)
        }

        # LPUSH: add the value to the head of the list
        Redix.pipeline(:redix, [
          [
            "LPUSH",
            state.redis_current_recent_measurements_list_name,
            Jason.encode!(data_for_redis)
          ],
          [
            "LTRIM",
            state.redis_current_recent_measurements_list_name,
            0,
            @number_of_current_entries - 1
          ]
        ])

        {:noreply, Map.replace(state, :last_stored_timestamp, message.timestamp)}
      end
    end
  end

  @impl true
  def handle_cast(:store_water_tick, state) do
    Logger.info("Backends.RedisBackend: Storing water tick in Redis")

    Redix.pipeline(:redix, [
      ["LPUSH", state.redis_water_last_ticks_list_name, DateTime.utc_now()],
      # Only keep last two ticks
      ["LTRIM", state.redis_water_last_ticks_list_name, 0, 1]
    ])

    {:noreply, state}
  end
end
