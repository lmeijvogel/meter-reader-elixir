defmodule IntervalCalculatorTest do
  use ExUnit.Case
  doctest MeterReader.IntervalCalculator

  @subject MeterReader.IntervalCalculator

  test "finds the next interval to save" do
    now = ~T[01:01:00.000]

    assert @subject.seconds_to_next(now, 900) === 14 * 60

    just_before_hour = ~T[23:55:15.000]

    assert @subject.seconds_to_next(just_before_hour, 900) === 5 * 60 - 15
  end

  test "finds the next 5-minute interval to save" do
    now = ~T[01:01:00.000]

    assert @subject.seconds_to_next(now, 300) === 4 * 60

    just_before_hour = ~T[23:55:15.000]

    assert @subject.seconds_to_next(just_before_hour, 900) === 5 * 60 - 15
  end
end
