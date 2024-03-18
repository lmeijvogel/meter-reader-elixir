defmodule MeterReader.SolarEdgeReader do
  require Logger

  use GenServer

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

  def schedule_next_retrieve(state) do
    now = NaiveDateTime.local_now()

    next =
      next_retrieve_datetime(
        now,
        state[:start_hour],
        state[:end_hour],
        state[:interval_in_seconds],
        state[:interval_offset_in_seconds]
      )

    Logger.debug(
      "SolarEdgeReader: Scheduling next request at #{NaiveDateTime.to_string(next)} (#{NaiveDateTime.diff(next, now)} seconds)"
    )

    Process.send_after(
      __MODULE__,
      :retrieve_data,
      NaiveDateTime.diff(next, now) * 1000
    )
  end

  def next_retrieve_datetime(
        now,
        start_hour,
        end_hour,
        interval_in_seconds,
        interval_offset_in_seconds
      ) do
    seconds_to_next = MeterReader.IntervalCalculator.seconds_to_next(now, interval_in_seconds)

    # 'interval_offset_in_seconds' is a delay after measurement to make sure that SolarEdge stored the measurement
    next_retrieve_time =
      NaiveDateTime.add(now, seconds_to_next + interval_offset_in_seconds)

    if next_retrieve_time.hour < end_hour do
      next_retrieve_time
    else
      tomorrow = NaiveDateTime.add(now, 1, :day)

      # Do not take daylight savings time into account.
      #
      # The worst that can happen is that on the first day after changing the clocks,
      # it will start at 6:00 or at 08:00 instead of 07:00. 
      # Since we retrieve all measurements of the whole day every time, we won't miss
      # anything.
      NaiveDateTime.add(
        %{tomorrow | hour: start_hour, minute: 0, second: 0},
        interval_offset_in_seconds
      )
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def handle_cast(:retrieve_data, state) do
    Logger.info("SolarEdgeReader: Retrieving data")
    schedule_next_retrieve(state)

    {:ok, response_body} = perform_api_request(state)
    {:ok, message} = MeterReader.SolarEdgeMessageDecoder.decode_message(response_body)

    Backends.InfluxBackend.store_solaredge(message[:production])

    {:noreply, state}
  end

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
end
