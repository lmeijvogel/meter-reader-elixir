defmodule MeterReader.SolarEdgeMessageDecoder do
  def decode_json(message) do
    {:ok, json} = Jason.decode(message)

    decode_message(json)
  end

  def decode_message(json) do
    meters = json["energyDetails"]["meters"]
    production = Enum.find(meters, fn meter -> meter["type"] == "Production" end)
    values = Enum.map(production["values"], fn entry -> parse_entry(entry) end)

    cleaned_values = Enum.filter(values, fn value -> value[:value] != nil end)

    {:ok, production: cleaned_values}
  end

  def parse_entry(entry) do
    case NaiveDateTime.from_iso8601(entry["date"]) do
      {:ok, date} -> %{date: date, value: entry["value"]}
      {:error, _} -> %{date: NaiveDateTime.local_now(), value: nil}
    end
  end
end
