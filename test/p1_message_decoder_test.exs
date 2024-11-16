defmodule MeterReader.MessageDecoderTest do
  alias MeterReader.P1Message
  alias MeterReader.P1MessageDecoder
  use ExUnit.Case

  test "decodes message" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:waiting, state} =
      P1MessageDecoder.parse_line_int("/ABCDEFGHI-METER", %P1Message{}, message_start_marker)

    {:waiting, state} =
      P1MessageDecoder.parse_line_int(
        "0-0:1.0.0(240228101631W)",
        state,
        message_start_marker
      )

    {:waiting, state} =
      P1MessageDecoder.parse_line_int(
        "1-0:2.7.0(00.168*kW)",
        state,
        message_start_marker
      )

    {{:done, resulting_message}, state} =
      P1MessageDecoder.parse_line_int("!E62D", state, message_start_marker)

    assert state == %P1Message{}
    assert resulting_message.levering_current == 168.0
  end

  test "skips the rest of the message after an error" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:waiting, state} =
      P1MessageDecoder.parse_line_int("/ABCDEFGHI-METER", %P1Message{}, message_start_marker)

    # Submit an invalid field
    {:error, state} =
      P1MessageDecoder.parse_line_int(
        "0-0:1.0.0(INVALID_TIME)",
        state,
        message_start_marker
      )

    assert state == %P1Message{}

    # Add a new reading. This should not be processed
    {:waiting, state} =
      P1MessageDecoder.parse_line_int("1-0:2.7.0(00.168*kW)", state, message_start_marker)

    assert state == %P1Message{}

    {:waiting, state} = P1MessageDecoder.parse_line_int("!E62D", state, message_start_marker)

    # Start a new, valid message
    {:waiting, state} =
      P1MessageDecoder.parse_line_int("/ABCDEFGHI-METER", state, message_start_marker)

    {:waiting, state} =
      P1MessageDecoder.parse_line_int("1-0:1.7.0(00.300*kW)", state, message_start_marker)

    {{:done, resulting_message}, state} =
      P1MessageDecoder.parse_line_int("!E62D", state, message_start_marker)

    # The message should have the given field
    assert resulting_message == %P1Message{contains_start?: true, stroom_current: 300.0}

    # It should start with an empty state again
    assert state == %P1Message{}
  end
end
