defmodule MeterReader.P1Reader do
  require Logger

  use GenServer

  @impl true
  def init(p1_config) do
    {:ok, uart_pid} = Circuits.UART.start_link()

    if p1_config[:start] do
      Process.send_after(self(), :open_port, 0)
    end

    {:ok, %{uart_pid: uart_pid, p1_config: p1_config}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def handle_info(:open_port, state) do
    Circuits.UART.open(state.uart_pid, state.p1_config[:port],
      speed: state.p1_config[:speed],
      data_bits: state.p1_config[:data_bits],
      stop_bits: state.p1_config[:stop_bits],
      parity: state.p1_config[:parity],
      active: true
    )

    # Receive one message per line
    Circuits.UART.configure(state.uart_pid,
      framing: {Circuits.UART.Framing.Line, separator: "\r\n"}
    )

    {:noreply, state}
  end

  def handle_info({:circuits_uart, _uart_port, {:error, reason}}, state) do
    IO.puts("ERROR")
    IO.puts(reason)

    {:noreply, state}
  end

  def handle_info({:circuits_uart, _uart_port, data}, state) do
    case MeterReader.P1MessageDecoder.parse_line(data) do
      {:done, message} ->
        previous_message = MeterReader.P1MessageStore.get()

        if MeterReader.P1Message.valid?(message, previous_message) do
          MeterReader.P1MessageStore.set(message)

          Backends.RedisBackend.p1_message_received(message)
        else
          Logger.warning("P1Reader: Dropping invalid message")
          Logger.debug("Current:  #{message |> inspect}")
          Logger.debug("Previous: #{previous_message |> inspect}")
        end

      _ ->
        nil
    end

    {:noreply, state}
  end
end
