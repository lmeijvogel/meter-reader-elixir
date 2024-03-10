defmodule Backends.InfluxBackend do
  use GenServer

  def init(_opts) do
    {:ok, %{}}
  end

  def store_p1(message) do
    GenServer.call(__MODULE__, {:store_p1, message})
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

  def handle_call({:store_p1, message}, _from, state) do
    Backends.InfluxConnection.write([
      create_point("levering", message[:levering_dal] + message[:levering_piek]),
      create_point("stroom", message[:stroom_dal] + message[:stroom_piek]),
      create_point("gas", message[:gas])
    ])

    :ok =
      Backends.InfluxTemporaryDataConnection.write([
        %{
          measurement: "current",
          fields: %{current: message[:stroom_current], generation: message[:levering_current]}
        }
      ])

    {:reply, :ok, state}
  end

  def handle_cast({:store_water_tick}, state) do
    Backends.InfluxConnection.write(create_point("water", 0.5))

    {:noreply, state}
  end

  def handle_cast({:store_solaredge, data}, state) do
    mapped_data =
      Enum.map(data, fn el ->
        {:ok, datetime_with_tz} = DateTime.from_naive(el[:date], "Europe/Amsterdam")

        timestamp = DateTime.to_unix(datetime_with_tz)

        %{
          measurement: "opwekking",
          fields: %{opwekking: el[:value]},
          timestamp: timestamp
        }
      end)

    Backends.InfluxConnection.write(mapped_data,
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
