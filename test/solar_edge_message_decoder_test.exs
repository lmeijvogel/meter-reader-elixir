defmodule SolarEdgeMessageDecoderTest do
  use ExUnit.Case
  doctest MeterReader.SolarEdgeMessageDecoder

  test "parses the message correctly" do
    {:ok, result} = MeterReader.SolarEdgeMessageDecoder.decode_json(message())

    assert result[:production] == [
             %{
               date: NaiveDateTime.new!(2024, 3, 1, 7, 30, 0),
               value: 0.0
             },
             %{
               date: NaiveDateTime.new!(2024, 3, 1, 13, 0, 0),
               value: 118.0
             },
             %{
               date: NaiveDateTime.new!(2024, 3, 1, 13, 30, 0),
               value: 66.0
             },
             %{
               date: NaiveDateTime.new!(2024, 3, 1, 14, 0, 0),
               value: 54.0
             },
             %{
               date: NaiveDateTime.new!(2024, 3, 1, 14, 30, 0),
               value: 104.0
             },
             %{
               date: NaiveDateTime.new!(2024, 3, 1, 18, 0, 0),
               value: 0.0
             }
           ]
  end

  @doc """
  This test makes sure that if there's an invalid date somewhere,
  only that message is thrown away, not all the others in the same batch
  as well
  """

  test "skips invalid dates" do
    input = """
    {
      "energyDetails": {
        "timeUnit": "QUARTER_OF_AN_HOUR",
        "unit": "Wh",
        "meters": [
          {
            "type": "Production",
            "values": [
              {
                "date": "2024-03-01 07:00:00",
                "value": 123.0
              },
              {
                "date": "invalid!",
                "value": 112.0
              }
            ]
          }
        ]
      }
    }
    """

    {:ok, result} = MeterReader.SolarEdgeMessageDecoder.decode_json(input)

    assert result[:production] == [
             %{
               date: NaiveDateTime.new!(2024, 3, 1, 7, 0, 0),
               value: 123.0
             }
           ]
  end

  def message do
    """
    {
      "energyDetails": {
        "timeUnit": "QUARTER_OF_AN_HOUR",
        "unit": "Wh",
        "meters": [
          {
            "type": "Production",
            "values": [
              {
                "date": "2024-03-01 07:00:00"
              },
              {
                "date": "2024-03-01 07:30:00",
                "value": 0.0
              },
              {
                "date": "2024-03-01 13:00:00",
                "value": 118.0
              },
              {
                "date": "2024-03-01 13:30:00",
                "value": 66.0
              },
              {
                "date": "2024-03-01 14:00:00",
                "value": 54.0
              },
              {
                "date": "2024-03-01 14:30:00",
                "value": 104.0
              },
              {
                "date": "2024-03-01 18:00:00",
                "value": 0.0
              },
              {
                "date": "2024-03-01 18:30:00"
              }
            ]
          }
        ]
      }
    }
    """
  end
end
