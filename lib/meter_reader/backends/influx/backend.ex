defmodule Backends.Influx.Backend do
  require Logger
  use GenServer

  @impl true
  def init([]) do
    {:ok, %{}}
  end

  def store_p1(message) do
    GenServer.cast(__MODULE__, {:store_p1, message})
  end

  def store_temporary_p1(message) do
    GenServer.cast(__MODULE__, {:store_temporary_p1, message})
  end

  def store_water_tick do
    GenServer.cast(__MODULE__, {:store_water_tick})
  end

  def store_solaredge(data) do
    GenServer.cast(__MODULE__, {:store_solaredge, data})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def handle_cast({:store_p1, message}, state) do
    Logger.info("Influx.Backend: Storing P1 message")

    Backends.Influx.Connection.write([
      create_point("levering", message.levering_dal + message.levering_piek),
      create_point("stroom", message.stroom_dal + message.stroom_piek),
      create_point("gas", message.gas)
    ])

    {:noreply, state}
  end

  @impl true
  def handle_cast({:store_temporary_p1, message}, state) do
    :ok =
      Backends.Influx.TemporaryDataConnection.write(
        [
          %{
            measurement: "current",
            fields: %{current: message.stroom_current, generation: message.levering_current}
          }
        ],
        log: false
      )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:store_water_tick}, state) do
    Backends.Influx.Connection.write(create_point("water", 0.5), log: false)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:store_solaredge, data}, state) do
    mapped_data =
      Enum.map(data, fn el ->
        datetime =
          case DateTime.from_naive(el[:date], "Europe/Amsterdam") do
            {:ok, datetime_with_tz} -> datetime_with_tz
            {:gap, _, _} -> nil
            _ -> raise "Could not parse date #{el[:date] |> inspect}"
          end

        if datetime do
          timestamp = DateTime.to_unix(datetime)

          %{
            measurement: "opwekking",
            fields: %{opwekking: round(el[:value])},
            timestamp: timestamp
          }
        else
          Logger.warning("SolarEdge: Skipping invalid date #{el[:date] |> inspect}")
          nil
        end
      end)

    filtered_mapped_data = Enum.filter(mapped_data, fn el -> el != nil end)

    :ok =
      Backends.Influx.Connection.write(filtered_mapped_data,
        precision: :second
      )

    {:noreply, state}
  end

  def create_point(measurement, value) do
    %{
      measurement: measurement,
      fields: %{measurement => value}
    }
  end
end
