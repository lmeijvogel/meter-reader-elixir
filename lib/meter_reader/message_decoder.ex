defmodule MeterReader.MessageDecoder do
  @moduledoc """
  Decodes incoming P1 messages.

  P1 messages are received line-by-line, so we can only
  return a complete message when all processing is done.

  To make this work, `decode` either returns
  - {:added, decoded_message} which means that we're in progress but line was added,
  - {:done, decoded_message}, which means that the message is complete. `decoded_message` can be used.
  """
  def decode("", _, state) do
    {:added, state}
  end

  def decode(line, message_start_marker, state) do
    cond do
      # The message start marker starts with `/` and a known string
      String.starts_with?(line, message_start_marker) ->
        {:added, %{}}

      # The message end marker starts with `!` and a random string of 4 alphanumeric chars.
      String.starts_with?(line, "!") ->
        {:done, state}

      true ->
        [field | values] = String.split(line, ~r{[()]}, trim: true)

        updated_state = parse_parts(field, values, state)

        {:added, updated_state}
    end
  end

  def parse_parts("0-0:1.0.0", inputs, state) do
    raw_value = Enum.at(inputs, 0)

    year = String.slice(raw_value, 0, 2)
    month = String.slice(raw_value, 2, 2)
    date = String.slice(raw_value, 4, 2)
    hour = String.slice(raw_value, 6, 2)
    minute = String.slice(raw_value, 8, 2)
    second = String.slice(raw_value, 10, 2)

    formatted_timestamp = "20#{year}-#{month}-#{date} #{hour}:#{minute}:#{second}"

    Map.put(state, :timestamp, formatted_timestamp)
    Map.put(state, :timestamp, formatted_timestamp)
  end

  def parse_parts("1-0:2.7.0", inputs, state) do
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
