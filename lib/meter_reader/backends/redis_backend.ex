defmodule Backends.RedisBackend do
  require Logger

  use GenServer

  @number_of_current_entries 5

  @impl true
  def init(config) do
    state = %{
      redis_current_latest_measurements_list_name:
        config[:redis_current_latest_measurements_list_name],
      redis_water_last_ticks_list_name: config[:redis_water_last_ticks_list_name]
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
    if message != nil do
      power = message.stroom_current - message.levering_current

      # LPUSH: add the value to the head of the list
      Redix.pipeline(:redix, [
        ["LPUSH", state.redis_current_latest_measurements_list_name, round(power)],
        [
          "LTRIM",
          state.redis_current_latest_measurements_list_name,
          0,
          @number_of_current_entries - 1
        ]
      ])
    end

    {:noreply, state}
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
