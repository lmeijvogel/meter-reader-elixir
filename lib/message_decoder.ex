defmodule MeterReader.MessageDecoder do
  def decode("!E62D", state) do
    {:done, state}
  end

  def decode("/ABCDEFGHI-METER", _) do
    {:added, %{}}
  end

  def decode("", state) do
    {:added, state}
  end

  def decode(line, state) do
    [field | values] = String.split(line, ~r{[()]}, trim: true)

    updated_state = parse_parts(field, values, state)

    {:added, updated_state}
  end

  def parse_parts("1-0:22.7.0", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    Map.put(state, :levering_current, value * 1000)
  end

  def parse_parts("1-0:2.8.1", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    Map.put(state, :levering_dal, value)
  end

  def parse_parts("1-0:2.8.2", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    Map.put(state, :levering_piek, value)
  end

  def parse_parts("1-0:1.7.0", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    Map.put(state, :stroom_current, value * 1000)
  end

  def parse_parts("1-0:1.8.1", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    Map.put(state, :stroom_dal, value)
  end

  def parse_parts("1-0:1.8.2", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    Map.put(state, :stroom_piek, value)
  end

  def parse_parts("0-1:24.2.1", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 1))
    Map.put(state, :gas, value)
  end

  def parse_parts(_, _, state) do
    state
  end
end
