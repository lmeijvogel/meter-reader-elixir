defmodule MeterReader.P1Message do
  require Logger

  @moduledoc """
  Decodes incoming P1 messages.

  P1 messages are received line-by-line, so we can only
  return a complete message when all processing is done.

  To make this work, `decode` either returns
  - {:added, decoded_message} which means that we're in progress but line was added,
  - {:done, decoded_message}, which means that the message is complete. `decoded_message` can be used.
  """
  alias MeterReader.P1Message

  defstruct timestamp: nil,
            stroom_piek: nil,
            stroom_dal: nil,
            stroom_current: nil,
            levering_current: nil,
            levering_piek: nil,
            levering_dal: nil,
            gas: nil,
            contains_start?: false,
            complete?: false

  def decode("", _, state) do
    {:added, state}
  end

  def decode(line, message_start_marker, state) do
    cond do
      # The message start marker starts with `/` and a known string
      # We add a 'full_message' field so the client can validate that it indeed received a message
      # built from a whole message (not started halfway)
      String.starts_with?(line, message_start_marker) ->
        {:added, %P1Message{contains_start?: true}}

      # The message end marker starts with `!` and a random string of 4 alphanumeric chars.
      String.starts_with?(line, "!") ->
        {:done, %P1Message{state | complete?: state.contains_start?}}

      true ->
        [field | values] = String.split(line, ~r{[()]}, trim: true)

        updated_state = parse_parts(field, values, state)

        {:added, updated_state}
    end
  end

  @doc """
  Sometimes the measurements are invalid, e.g. a measurement is missing
  or is lower than the last measurement. In that case the message should be dropped.
  """
  def valid?(message, last_message) do
    cond do
      message.stroom_piek == nil -> false
      message.stroom_dal == nil -> false
      message.levering_piek == nil -> false
      message.levering_dal == nil -> false
      message.gas == nil -> false
      last_message == nil -> true
      message.stroom_piek < last_message.stroom_piek -> false
      message.stroom_dal < last_message.stroom_dal -> false
      message.levering_piek < last_message.levering_piek -> false
      message.levering_dal < last_message.levering_dal -> false
      message.gas < last_message.gas -> false
      true -> true
    end
  end

  defp parse_parts("0-0:1.0.0", inputs, state) do
    raw_value = Enum.at(inputs, 0)

    values =
      raw_value
      |> String.to_charlist()
      |> Enum.chunk_every(2)
      |> Enum.map(fn cl -> "#{cl}" end)
      |> Enum.filter(&Regex.match?(~r[\d+], &1))
      |> Enum.map(&String.to_integer(&1))

    naive_timestamp =
      NaiveDateTime.new!(
        2000 + Enum.at(values, 0),
        Enum.at(values, 1),
        Enum.at(values, 2),
        Enum.at(values, 3),
        Enum.at(values, 4),
        Enum.at(values, 5)
      )

    timestamp = DateTime.from_naive!(naive_timestamp, "Europe/Amsterdam")

    %P1Message{state | timestamp: timestamp}
  end

  defp parse_parts("1-0:2.7.0", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    %P1Message{state | levering_current: value * 1000}
  end

  defp parse_parts("1-0:2.8.1", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))

    %P1Message{state | levering_dal: value}
  end

  defp parse_parts("1-0:2.8.2", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    %P1Message{state | levering_piek: value}
  end

  defp parse_parts("1-0:1.7.0", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    %P1Message{state | stroom_current: value * 1000}
  end

  defp parse_parts("1-0:1.8.1", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    %P1Message{state | stroom_dal: value}
  end

  defp parse_parts("1-0:1.8.2", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    %P1Message{state | stroom_piek: value}
  end

  defp parse_parts("0-1:24.2.1", inputs, state) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 1))
    %P1Message{state | gas: value}
  end

  defp parse_parts(_, _, state) do
    state
  end
end
