defmodule Backends.Postgres.TempBackend do
  require Logger
  use GenServer

  @impl true
  def init(config) do
    # Ideally, this should be started from the Supervisor, but Postgrex starts
    # its own ConnectionPool with a (maybe?) fixed id, causing `mix` to crash.
    #
    # This doesn't happen if I start it here manually, so let's keep it here
    # for now, since this module will be removed somewhere in the future
    # anyway.
    {:ok, pid} = Postgrex.start_link(config)

    {:ok, %{pid: pid}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def store_p1(p1_message) do
    GenServer.call(__MODULE__, {:store_p1, p1_message})
  end

  def store_water do
    GenServer.call(__MODULE__, {:store_water})
  end

  def store_solaredge(production_data) do
    GenServer.call(__MODULE__, {:store_solaredge, production_data})
  end

  @impl true
  def handle_call({:store_p1, p1_message}, _from, state) do
    Logger.debug("Postgres.TempBackend: Storing p1 message: #{inspect(p1_message)}")

    {:ok, _} = store_gas(p1_message, p1_message.timestamp, state)
    {:ok, _} = store_power(p1_message, p1_message.timestamp, state)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:store_water}, _from, state) do
    Logger.debug("Postgres.TempBackend: Storing water tick in postgres")

    query = """
      INSERT INTO water(created, usage_dl) VALUES($1::timestamp, $2::integer);
    """

    params = [
      DateTime.now!("Europe/Amsterdam"),
      5
    ]

    Postgrex.query(state[:pid], query, params)

    {:reply, :ok, state}
  end

  def handle_call({:store_solaredge, production_data}, _from, state) do
    item_count = length(production_data)

    if item_count > 0 do
      Logger.debug("Postgres.TempBackend: Storing #{item_count} SolarEdge entries")

      placeholders =
        Enum.map(0..(item_count - 1), fn i ->
          "($#{i * 2 + 1}::timestamp, $#{i * 2 + 2}::integer)"
        end)

      formatted_placeholders = Enum.join(placeholders, ", ")

      params =
        Enum.flat_map(production_data, fn row ->
          [row.timestamp, row.value]
        end)

      query = """
        INSERT INTO generation(created, generation_wh) VALUES #{formatted_placeholders}
        ON CONFLICT (created) DO UPDATE
        SET generation_wh = EXCLUDED.generation_wh
      """

      {:ok, _result} = Postgrex.query(state[:pid], query, params)
    else
      Logger.debug("Postgres.TempBackend: No new SolarEdge entries")
    end

    {:reply, state, state}
  end

  defp store_gas(p1_message, timestamp, state) do
    query = """
      INSERT INTO gas(created, cumulative_total_dm3) VALUES($1::timestamp, $2::integer);
    """

    params = [
      timestamp,
      round(p1_message.gas * 1000)
    ]

    Postgrex.query(state[:pid], query, params)
  end

  defp store_power(p1_message, timestamp, state) do
    query =
      "INSERT INTO power(created, cumulative_from_network_wh, cumulative_to_network_wh) VALUES($1::timestamp, $2::integer, $3::integer)"

    params = [
      timestamp,
      round((p1_message.stroom_dal + p1_message.stroom_piek) * 1000),
      round((p1_message.levering_dal + p1_message.levering_piek) * 1000)
    ]

    Postgrex.query(state[:pid], query, params)
  end
end
