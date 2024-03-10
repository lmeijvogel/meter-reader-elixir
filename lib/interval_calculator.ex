defmodule MeterReader.IntervalCalculator do
  def seconds_to_next(now, interval_in_seconds) do
    minute = now.minute
    second = now.second

    distance_from_previous = Integer.mod(minute * 60 + second, interval_in_seconds)

    interval_in_seconds - distance_from_previous
  end
end
