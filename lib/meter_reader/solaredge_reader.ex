defmodule MeterReader.SolarEdgeReader do
  require Logger

  use GenServer

  @impl true
  def init(opts) do
    state = %{
      host: opts[:host],
      site_id: opts[:site_id],
      api_key: opts[:api_key],
      interval_in_seconds: opts[:interval_in_seconds],
      interval_offset_in_seconds: opts[:interval_offset_in_seconds],
      start_hour: opts[:start_hour],
      end_hour: opts[:end_hour]
    }

    if opts[:start] do
      schedule_next_retrieve(state)
    end

    {:ok, state}
  end

  def retrieve_data do
    GenServer.cast(__MODULE__, :retrieve_data)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def handle_cast(:retrieve_data, state) do
    schedule_next_retrieve(state)

    {:ok, response_body} = perform_api_request(state)
    {:ok, message} = MeterReader.SolarEdgeMessageDecoder.decode_message(response_body)

    Backends.Influx.Backend.store_solaredge(message[:production])

    mapped_production =
      Enum.map(message[:production], fn row ->
        %{timestamp: DateTime.from_naive!(row.date, "Europe/Amsterdam"), value: row.value}
      end)

    if Backends.Postgres.ProdEnabledStore.enabled?() do
      Backends.Postgres.Backend.store_solaredge(mapped_production)
    end

    Backends.Postgres.TempBackend.store_solaredge(mapped_production)

    {:noreply, state}
  end

  @impl true
  def handle_info(:retrieve_data, state) do
    retrieve_data()

    {:noreply, state}
  end

  def perform_api_request(state) do
    now = NaiveDateTime.local_now()

    start_time = NaiveDateTime.new!(now.year, now.month, now.day, 0, 0, 0)
    end_time = NaiveDateTime.new!(now.year, now.month, now.day, 23, 59, 59)

    url = "#{state[:host]}/site/#{state[:site_id]}/energyDetails"
    Logger.debug("SolarEdgeReader: Requesting URL #{url}")

    {:ok, response} =
      Req.get(url,
        params: [
          api_key: state[:api_key],
          timeUnit: "QUARTER_OF_AN_HOUR",
          startTime: start_time,
          endTime: end_time
        ]
      )

    {:ok, response.body}
  end

  defp schedule_next_retrieve(state) do
    Scheduler.schedule_next(
      {self(), :retrieve_data},
      "SolarEdge",
      {state[:start_hour], state[:end_hour], state[:interval_in_seconds],
       state[:interval_offset_in_seconds]}
    )
  end
end
