defmodule WaterReaderTest do
  use ExUnit.Case
  doctest MeterReader.WaterReader

  @subject MeterReader.WaterReader

  test "recognizes USAGE messages" do
    result = @subject.is_usage_message("USAGE 12")

    assert result
  end

  test "ignores non-USAGE messages" do
    result = @subject.is_usage_message("TICK")

    assert !result
  end
end
