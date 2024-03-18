defmodule MeterReader.IntervalCalculator do
  @doc """
  Returns the number of seconds until the next moment of action, e.g.
  if the interval is 300 (5 minutes), this will return the number of seconds until
  the time is divisible by 5 minutes (e.g. :00, :05, :10, :15, ...)
  """
  def seconds_to_next(now, interval_in_seconds) do
    minute = now.minute
    second = now.second

    distance_from_previous = Integer.mod(minute * 60 + second, interval_in_seconds)

    interval_in_seconds - distance_from_previous
  end
end
