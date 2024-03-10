defmodule SolarEdgeReaderTest do
  use ExUnit.Case
  doctest MeterReader.SolarEdgeReader

  test "returns the next time if it's before the daily end time" do
    now = NaiveDateTime.new!(2024, 10, 10, 15, 5, 0)

    start_hour = 7
    end_hour = 22
    interval_in_seconds = 15 * 60
    interval_offset_in_seconds = 2 * 60

    result =
      MeterReader.SolarEdgeReader.next_retrieve_datetime(
        now,
        start_hour,
        end_hour,
        interval_in_seconds,
        interval_offset_in_seconds
      )

    assert result == NaiveDateTime.new!(2024, 10, 10, 15, 17, 0)
  end

  test "returns tomorrow morning if it's after the end time" do
    now = NaiveDateTime.new!(2024, 10, 10, 21, 5, 0)

    # Intentionally different from the one in production settings, to make sure that we
    # read the function parameters to the function
    start_hour = 10
    end_hour = 21
    interval_in_seconds = 15 * 60
    interval_offset_in_seconds = 2 * 60

    result =
      MeterReader.SolarEdgeReader.next_retrieve_datetime(
        now,
        start_hour,
        end_hour,
        interval_in_seconds,
        interval_offset_in_seconds
      )

    assert result == NaiveDateTime.new!(2024, 10, 11, 10, 2, 0)
  end
end
