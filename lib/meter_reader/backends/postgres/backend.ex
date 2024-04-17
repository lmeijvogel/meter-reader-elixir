defmodule Backends.Postgres.Backend do
  require Logger
  use GenServer

  @impl true
  def init(_) do
    {:ok, %{}}
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
    Logger.debug("Storing p1 message in postgres: #{inspect(p1_message)}")

    {:ok, timestamp} = get_timestamp(p1_message)

    {:ok, _} = store_gas(p1_message, timestamp, state)
    {:ok, _} = store_power(p1_message, timestamp, state)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:store_water}, _from, state) do
    Logger.debug("PostgresBackend: Storing water tick in postgres")

    query = """
      INSERT INTO water(created, usage_dl) VALUES($1::timestamp, $2::integer);
    """

    params = [
      DateTime.now!("Europe/Amsterdam"),
      5
    ]

    Postgrex.query(:meter_reader_postgrex, query, params)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:store_solaredge, production_data}, _from, state) do
    existing_timestamps = existing_timestamps(Date.utc_today(), state)

    data_to_insert =
      Enum.reject(production_data, fn row ->
        Enum.find(existing_timestamps, fn ts ->
          DateTime.compare(row.timestamp, ts) == :eq
        end)
      end)

    item_count = length(data_to_insert)

    if item_count > 0 do
      Logger.debug("PostgresBackend: Storing #{item_count} SolarEdge entries")

      placeholders =
        Enum.map(0..(item_count - 1), fn i ->
          "($#{i * 2 + 1}::timestamp, $#{i * 2 + 2}::integer)"
        end)

      formatted_placeholders = Enum.join(placeholders, ", ")

      params =
        Enum.flat_map(data_to_insert, fn row ->
          [row.timestamp, row.value]
        end)

      query = """
        INSERT INTO generation(created, generation_wh) VALUES #{formatted_placeholders}
      """

      {:ok, _result} = Postgrex.query(:meter_reader_postgrex, query, params)
    else
      Logger.debug("PostgresBackend: No new SolarEdge entries")
    end

    {:reply, state, state}
  end

  defp store_gas(p1_message, timestamp, state) do
    query = """
      INSERT INTO gas(created, cumulative_total_dm3) VALUES($1::timestamp, $2::integer);
    """

    params = [
      timestamp,
      round(p1_message[:gas] * 1000)
    ]

    Postgrex.query(:meter_reader_postgrex, query, params)
  end

  defp store_power(p1_message, timestamp, state) do
    query =
      "INSERT INTO power(created, cumulative_from_network_wh, cumulative_to_network_wh) VALUES($1::timestamp, $2::integer, $3::integer)"

    params = [
      timestamp,
      round((p1_message[:stroom_dal] + p1_message[:stroom_piek]) * 1000),
      round((p1_message[:levering_dal] + p1_message[:levering_piek]) * 1000)
    ]

    Postgrex.query(:meter_reader_postgrex, query, params)
  end

  defp existing_timestamps(date, _state) do
    existing_timestamps_query = "SELECT created FROM generation WHERE created >= $1::date"

    {:ok, result} = Postgrex.query(:meter_reader_postgrex, existing_timestamps_query, [date])

    Enum.map(result.rows, fn row -> List.first(row) end)
  end

  def get_timestamp(p1_message) do
    {:ok, naive_datetime} = NaiveDateTime.from_iso8601(p1_message[:timestamp])
    DateTime.from_naive(naive_datetime, "Europe/Amsterdam")
  end

  def print_error(error) do
    IO.puts("Error while inserting into database: #{error.message}")
  end
end
