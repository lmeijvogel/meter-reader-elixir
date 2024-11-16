defmodule MeterReader.P1Message do
  require Logger

  @moduledoc """
  Decodes incoming P1 messages.

  P1 messages are received line-by-line, so we can only
  return a complete message when all processing is done.

  To make this work, `decode` either returns
  - :waiting, which means that we're waiting for a message to start.
  - {:added, decoded_message}, which means that we're in progress and a line was added,
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
            contains_start?: false

  def decode("", _, partial_message, _now) do
    {:added, partial_message}
  end

  # When we're building a message (i.e. we received a start marker and are receiving lines)
  # We do return the partial message, but that is only intended for state-keeping, and
  # is not intended to be used outside this module.
  #
  # Only when we return {:done, message}, the message is valid for use.
  def decode(line, message_start_marker, partial_message, now) do
    trimmed_line = String.trim(line)

    cond do
      # The message start marker starts with `/` and a known string
      # We only return the message when it 
      # We add a 'full_message' field so the client can validate that it indeed received a message
      # built from a whole message (not started halfway)
      String.starts_with?(trimmed_line, message_start_marker) ->
        {:added, %P1Message{contains_start?: true}}

      # If we didn't get the message start and the message was not started yet
      # keep waiting until we do get a message start.
      !partial_message.contains_start? ->
        :waiting

      # The message end marker starts with `!` and a random string of 4 alphanumeric chars.
      # If we also have a message start, then this is a complete message and we can return it.
      String.starts_with?(trimmed_line, "!") ->
        {:done, partial_message}

      true ->
        [field | values] = String.split(trimmed_line, ~r{[()]}, trim: true)

        case parse_parts(field, values, partial_message, now) do
          {:ok, updated_state} ->
            {:added, updated_state}

          _ ->
            Logger.warning("Invalid P1 message part for #{field}: #{values}.")
            :error
        end
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

  defp parse_parts("0-0:1.0.0", inputs, partial_message, now) do
    try do
      raw_value = Enum.at(inputs, 0)

      values =
        raw_value
        |> String.to_charlist()
        |> Enum.chunk_every(2)
        |> Enum.map(fn cl -> "#{cl}" end)
        |> Enum.filter(&Regex.match?(~r[\d+], &1))
        |> Enum.map(&String.to_integer(&1))

      result =
        NaiveDateTime.new(
          2000 + Enum.at(values, 0),
          Enum.at(values, 1),
          Enum.at(values, 2),
          Enum.at(values, 3),
          Enum.at(values, 4),
          Enum.at(values, 5)
        )

      case result do
        {:ok, naive_timestamp} ->
          timestamp =
            parse_timestamp(DateTime.from_naive(naive_timestamp, "Europe/Amsterdam"), now)

          {:ok, %P1Message{partial_message | timestamp: timestamp}}

        _ ->
          {:error, partial_message}
      end
    rescue
      _ ->
        {:error, %P1Message{}}
    end
  end

  defp parse_parts("1-0:2.7.0", inputs, partial_message, _now) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    {:ok, %P1Message{partial_message | levering_current: value * 1000}}
  end

  defp parse_parts("1-0:2.8.1", inputs, partial_message, _now) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))

    {:ok, %P1Message{partial_message | levering_dal: value}}
  end

  defp parse_parts("1-0:2.8.2", inputs, partial_message, _now) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    {:ok, %P1Message{partial_message | levering_piek: value}}
  end

  defp parse_parts("1-0:1.7.0", inputs, partial_message, _now) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    {:ok, %P1Message{partial_message | stroom_current: value * 1000}}
  end

  defp parse_parts("1-0:1.8.1", inputs, partial_message, _now) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    {:ok, %P1Message{partial_message | stroom_dal: value}}
  end

  defp parse_parts("1-0:1.8.2", inputs, partial_message, _now) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 0))
    {:ok, %P1Message{partial_message | stroom_piek: value}}
  end

  defp parse_parts("0-1:24.2.1", inputs, partial_message, _now) do
    {value, _suffix} = Float.parse(Enum.at(inputs, 1))
    {:ok, %P1Message{partial_message | gas: value}}
  end

  defp parse_parts(_, _, partial_message, _now) do
    {:ok, partial_message}
  end

  defp parse_timestamp({:ok, date}, _now) do
    date
  end

  # It is possible for a time to be ambiguous, for example,
  # it can be either CEST and CET.
  #
  # This chooses the date depending on what the system time zone is.
  defp parse_timestamp({:ambiguous, first, second}, now) do
    Enum.find([first, second], fn dt ->
      dt.time_zone == now.time_zone && dt.zone_abbr == now.zone_abbr
    end)
  end
end
