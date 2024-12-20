defmodule MessageDecoderTest do
  alias MeterReader.P1Message
  use ExUnit.Case
  doctest MeterReader.P1Message

  @subject MeterReader.P1Message

  test "decode start of message" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, result} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    assert result.contains_start?
  end

  test "decode empty line" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)
    {:added, state} = @subject.decode("", message_start_marker, state, nil)

    {result, _} = @subject.decode("!E62D", message_start_marker, state, nil)

    assert result == :done
  end

  test "decode timestamp" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    {:added, state} =
      @subject.decode("0-0:1.0.0(240228101631W)", message_start_marker, state, nil)

    {:done, state} = @subject.decode("!E62D", message_start_marker, state, nil)

    naive_datetime = NaiveDateTime.new!(2024, 2, 28, 10, 16, 31)

    assert state.timestamp == DateTime.from_naive!(naive_datetime, "Europe/Amsterdam")
  end

  # At the end of DST, the clock will go backward one hour from 03:00 to 02:00.
  # Any time during that period can be from either timezone.
  # For example: 02:30 can be 02:30 CET or 02:30 CEST.
  test "decode ambiguous timestamp in CEST" do
    message_start_marker = "/ABCDEFGHI-METER"

    naive_datetime = NaiveDateTime.new!(2024, 10, 27, 02, 59, 58)

    {:ambiguous, now, _} = DateTime.from_naive(naive_datetime, "Europe/Amsterdam")

    assert now.zone_abbr == "CEST"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    {:added, state} =
      @subject.decode("0-0:1.0.0(241027025958W)", message_start_marker, state, now)

    {:done, state} = @subject.decode("!E62D", message_start_marker, state, nil)

    assert state.timestamp == now
  end

  test "decode ambiguous timestamp in CET" do
    message_start_marker = "/ABCDEFGHI-METER"

    naive_datetime = NaiveDateTime.new!(2024, 10, 27, 02, 59, 58)

    {:ambiguous, _, now} = DateTime.from_naive(naive_datetime, "Europe/Amsterdam")

    assert now.zone_abbr == "CET"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    {:added, state} =
      @subject.decode("0-0:1.0.0(241027025958W)", message_start_marker, state, now)

    {:done, state} = @subject.decode("!E62D", message_start_marker, state, nil)

    assert state.timestamp == now
  end

  test "decode invalid timestamp" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    # Some valid data to check that it's removed later on
    {:added, state} = @subject.decode("1-0:1.7.0(00.300*kW)", message_start_marker, state, nil)

    assert state.stroom_current != nil

    assert @subject.decode(
             "0-0:1.0.0(241331256161W)",
             message_start_marker,
             state,
             DateTime.now!("Europe/Amsterdam")
           ) ==
             :error
  end

  test "decode levering_current" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)
    {:added, state} = @subject.decode("1-0:2.7.0(00.168*kW)", message_start_marker, state, nil)
    {:done, state} = @subject.decode("!3C07", message_start_marker, state, nil)

    assert state.levering_current == 168
  end

  test "decode levering_dal" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    {:added, state} =
      @subject.decode("1-0:2.8.1(000934.490*kWh)", message_start_marker, state, nil)

    {:done, state} = @subject.decode("!AFFE", message_start_marker, state, nil)

    assert state.levering_dal == 934.490
  end

  test "decode levering_piek" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    {:added, state} =
      @subject.decode("1-0:2.8.2(002115.131*kWh)", message_start_marker, state, nil)

    {:done, state} = @subject.decode("!E62D", message_start_marker, state, nil)

    assert state.levering_piek == 2115.131
  end

  test "decode stroom_current" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)
    {:added, state} = @subject.decode("1-0:1.7.0(00.300*kW)", message_start_marker, state, nil)
    {:done, state} = @subject.decode("!E62D", message_start_marker, state, nil)

    assert state.stroom_current == 300
  end

  test "decode stroom_dal" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    {:added, state} =
      @subject.decode("1-0:1.8.1(003900.313*kWh)", message_start_marker, state, nil)

    {:done, state} = @subject.decode("!E62D", message_start_marker, state, nil)

    assert state.stroom_dal == 3900.313
  end

  test "decode stroom_piek" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    {:added, state} =
      @subject.decode("1-0:1.8.2(004184.285*kWh)", message_start_marker, state, nil)

    {:done, state} = @subject.decode("!E62D", message_start_marker, state, nil)

    assert state.stroom_piek == 4184.285
  end

  test "decode gas" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    {:added, state} =
      @subject.decode("0-1:24.2.1(240224163506W)(03991.882*m3)", message_start_marker, state, nil)

    {:done, state} = @subject.decode("!E62D", message_start_marker, state, nil)

    assert state.gas == 3991.882
  end

  test "decode multiple" do
    message_start_marker = "/ABCDEFGHI-METER"

    {:added, state} = @subject.decode("/ABCDEFGHI-METER", message_start_marker, %{}, nil)

    {:added, state} =
      @subject.decode("0-1:24.2.1(240224163506W)(03991.882*m3)", message_start_marker, state, nil)

    {:added, state} =
      @subject.decode("1-0:1.8.2(004184.285*kWh)", message_start_marker, state, nil)

    {:done, state} = @subject.decode("!E62D", message_start_marker, state, nil)

    assert state.gas == 3991.882
    assert state.stroom_piek == 4184.285
  end

  test "decode when starting halfway through a message" do
    message_start_marker = "/ABCDEFGHI-METER"

    assert @subject.decode(
             "0-1:24.2.1(240224163506W)(03991.882*m3)",
             message_start_marker,
             %MeterReader.P1Message{},
             nil
           ) == :waiting

    assert @subject.decode("!E62D", message_start_marker, %P1Message{}, nil) == :waiting

    irrelevant_state = nil

    {:added, state} =
      @subject.decode("/ABCDEFGHI-METER", message_start_marker, irrelevant_state, nil)

    {:added, state} =
      @subject.decode("0-1:24.2.1(240224163506W)(03991.882*m3)", message_start_marker, state, nil)

    {:done, state} = @subject.decode("!E62D", message_start_marker, state, nil)

    assert state.gas == 3991.882
  end
end

# /ABCDEFGHI-METER
#
# 1-3:0.2.8(50)
# 0-0:1.0.0(240224163846W)
# 0-0:96.1.1(4530303539303030303030353936363139)
# 1-0:1.8.1(003900.313*kWh)
# 1-0:1.8.2(004184.285*kWh)
# 1-0:2.8.1(000934.490*kWh)
# 1-0:2.8.2(002115.131*kWh)
# 0-0:96.14.0(0001)
# 1-0:1.7.0(00.000*kW)
# 1-0:2.7.0(00.168*kW)
# 0-0:96.7.21(00005)
# 0-0:96.7.9(00002)
# 1-0:99.97.0(2)(0-0:96.7.19)(220808111826S)(0000000407*s)(210516114015S)(0000003077*s)
# 1-0:32.32.0(00014)
# 1-0:32.36.0(00000)
# 0-0:96.13.0()
# 1-0:32.7.0(235.7*V)
# 1-0:31.7.0(002*A)
# 1-0:21.7.0(00.000*kW)
# 1-0:22.7.0(00.168*kW)
# 0-1:24.1.0(003)
# 0-1:96.1.0(4730303634303032303037303331343230)
# 0-1:24.2.1(240224163506W)(03991.882*m3)
# !E62D
# 
