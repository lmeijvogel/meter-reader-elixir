defmodule Scheduler do
  require Logger

  def schedule_next({pid, message}, sender_name, specs) do
    now = NaiveDateTime.local_now()

    next =
      next_datetime(
        now,
        specs
      )

    Logger.info(
      "#{sender_name}: Scheduling next #{message} at #{NaiveDateTime.to_string(next)} (#{NaiveDateTime.diff(next, now)} seconds)"
    )

    Process.send_after(
      pid,
      message,
      NaiveDateTime.diff(next, now) * 1000
    )
  end

  def next_datetime(now, {interval_in_seconds}) do
    next_datetime(now, {-1, 25, interval_in_seconds, 0})
  end

  def next_datetime(
        now,
        {
          start_hour,
          end_hour,
          interval_in_seconds,
          interval_offset_in_seconds
        }
      ) do
    seconds_to_next = MeterReader.IntervalCalculator.seconds_to_next(now, interval_in_seconds)

    # Normally, the interval is treated as a kind of "modulus", e.g. if the interval is 10,
    # then the message will send at the next multiple of 10, so not e.g. at 15.
    #
    # 'interval_offset_in_seconds' is an optional after that calculated time, so if the calculated time is 10 and the delay is 3,
    # then the request will be sent at 13.
    next_retrieve_time =
      NaiveDateTime.add(now, seconds_to_next + interval_offset_in_seconds)

    if next_retrieve_time.hour < end_hour do
      next_retrieve_time
    else
      tomorrow = NaiveDateTime.add(now, 1, :day)

      # Do not take daylight savings time into account for scheduling the retrieval.
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
end
