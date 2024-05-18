defmodule Backends.Postgres.Backend do
  require Logger
  use GenServer

  @impl true
  def init([]) do
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

  def store_temperatures(temperatures, created) do
    GenServer.call(__MODULE__, {:store_temperatures, temperatures, created})
  end

  @impl true
  def handle_call({:store_p1, p1_message}, _from, state) do
    Logger.info("Postgres.Backend: Storing P1 data")
    :ok = store_gas(p1_message, p1_message.timestamp)
    :ok = store_power(p1_message, p1_message.timestamp)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:store_water}, _from, state) do
    Logger.debug("Postgres.Backend: Storing water tick in postgres")

    query = """
      INSERT INTO water(created, usage_dl) VALUES($1::timestamp, $2::integer);
    """

    params = [
      DateTime.now!("Europe/Amsterdam"),
      5
    ]

    if enabled?() do
      Postgrex.query(:meter_reader_postgrex, query, params)
    else
      Logger.debug("Postgres.Backend.store_water: enabled == false, not writing")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:store_solaredge, production_data}, _from, state) do
    item_count = length(production_data)

    if item_count > 0 do
      Logger.debug("Postgres.Backend: Storing #{item_count} SolarEdge entries")

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

      if enabled?() do
        {:ok, _result} = Postgrex.query(:meter_reader_postgrex, query, params)
      else
        Logger.debug("Postgres.Backend.store_solaredge: enabled == false, not writing")
      end
    else
      Logger.debug("Postgres.Backend: No new SolarEdge entries")
    end

    {:reply, state, state}
  end

  @impl true
  def handle_call({:store_temperatures, temperatures, created}, _from, state) do
    fields = Map.keys(temperatures)

    values =
      temperatures
      |> Map.values()
      |> Enum.map(fn val -> trunc(val * 10) end)

    placeholders =
      Enum.map(0..(length(values) - 1), fn i ->
        "$#{i + 2}::integer"
      end)

    query = """
      INSERT INTO temperatures(created, #{Enum.join(fields, ", ")}) VALUES ($1::timestamp, #{Enum.join(placeholders, ", ")})
    """

    params = [created] ++ values

    {:ok, _result} = Postgrex.query(:meter_reader_postgrex, query, params)

    {:reply, state, state}
  end

  defp store_gas(p1_message, timestamp) do
    query = """
      INSERT INTO gas(created, cumulative_total_dm3) VALUES($1::timestamp, $2::integer);
    """

    params = [
      timestamp,
      round(p1_message.gas * 1000)
    ]

    if enabled?() do
      {:ok, _} = Postgrex.query(:meter_reader_postgrex, query, params)
    else
      Logger.debug("Postgres.Backend.store_gas: enabled == false, not writing")
    end

    :ok
  end

  defp store_power(p1_message, timestamp) do
    query =
      "INSERT INTO power(created, cumulative_from_network_wh, cumulative_to_network_wh) VALUES($1::timestamp, $2::integer, $3::integer)"

    params = [
      timestamp,
      round((p1_message.stroom_dal + p1_message.stroom_piek) * 1000),
      round((p1_message.levering_dal + p1_message.levering_piek) * 1000)
    ]

    if enabled?() do
      {:ok, _} = Postgrex.query(:meter_reader_postgrex, query, params)
    else
      Logger.debug("Postgres.Backend.store_power: enabled == false, not writing")
    end

    :ok
  end

  defp enabled? do
    Backends.Postgres.ProdEnabledStore.enabled?()
  end
end
