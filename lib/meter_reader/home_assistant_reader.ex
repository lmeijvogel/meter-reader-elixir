defmodule MeterReader.HomeAssistantReader do
  require Logger

  use GenServer

  @impl true
  def init(opts) do
    state = %{
      interval_in_seconds: opts[:interval_in_seconds],
      host: opts[:host],
      api_key: opts[:api_key],
      sensors: opts[:sensors]
    }

    if opts[:start] do
      schedule_next_retrieve(state)
    end

    {:ok, state}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def handle_info(:retrieve_data, state) do
    temperatures =
      Enum.reduce(state.sensors, %{}, fn {key, field}, acc ->
        response = perform_api_request!("sensor.#{key}", state)
        {:ok, temperature} = extract_temperature(response)

        Map.put(acc, field, temperature)
      end)

    Backends.Postgres.Backend.store_temperatures(temperatures, DateTime.now!("Europe/Amsterdam"))

    schedule_next_retrieve(state)

    {:noreply, state}
  end

  defp perform_api_request(sensor_id, state) do
    url = "#{state[:host]}/api/states/#{sensor_id}"

    {:ok, response} =
      Req.get(url,
        auth: {:bearer, state[:api_key]},
        headers: %{"Content-Type": "application/json"}
      )

    {:ok, response.body}
  end

  defp perform_api_request!(sensor_id, state) do
    {:ok, response} = perform_api_request(sensor_id, state)

    response
  end

  defp extract_temperature(message) do
    {:ok, String.to_float(message["state"])}
  end

  defp schedule_next_retrieve(state) do
    MeterReader.Scheduler.schedule_next(
      {self(), :retrieve_data},
      "HomeAssistantReader",
      {state.interval_in_seconds}
    )
  end
end
