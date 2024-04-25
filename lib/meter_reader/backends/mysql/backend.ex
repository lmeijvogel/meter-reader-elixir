defmodule Backends.Mysql.Backend do
  require Logger
  use GenServer

  @impl true
  def init([]) do
    {:ok, %{}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def save(p1_message, water_ticks) do
    GenServer.call(__MODULE__, {:save, p1_message, water_ticks})
  end

  @impl true
  def handle_call({:save, p1_message, water_ticks}, _from, state) do
    Logger.debug(
      "Saving P1 message to MariaDB: #{inspect(Map.put(p1_message, :water, water_ticks))}"
    )

    query =
      "INSERT INTO measurements(time_stamp, time_stamp_utc, stroom, levering, gas, water) VALUES(
    ?,
    ?,
    ?,
    ?,
    ?,
    ?)"

    {:ok, now} = DateTime.now("Etc/UTC")

    params = [
      p1_message.timestamp,
      now |> DateTime.to_naive() |> NaiveDateTime.to_iso8601(),
      p1_message.stroom_piek + p1_message.stroom_dal,
      p1_message.levering_piek + p1_message.levering_dal,
      p1_message.gas,
      water_ticks
    ]

    case MyXQL.query(:myxql, query, params) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  def print_error(error) do
    IO.puts("Error while inserting into database: #{error.message}")
  end
end
