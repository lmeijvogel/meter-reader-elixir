defmodule MeterReader.WaterReader do
  require Logger
  use GenServer

  @impl true
  def init(port_config) do
    {:ok, uart_pid} = Circuits.UART.start_link()

    if port_config[:start] do
      Process.send_after(self(), :open_port, 0)
    end

    {:ok, %{uart_pid: uart_pid, port_config: port_config}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def handle_info(:open_port, state) do
    Circuits.UART.open(state.uart_pid, state.port_config[:port],
      speed: state.port_config[:speed],
      data_bits: state.port_config[:data_bits],
      stop_bits: state.port_config[:stop_bits],
      parity: state.port_config[:parity],
      active: true
    )

    # Receive one message per line
    Circuits.UART.configure(state.uart_pid,
      framing: {Circuits.UART.Framing.Line, separator: "\n"}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_uart, _uart_port, {:error, reason}}, state) do
    Logger.error("WaterReader: ERROR: #{reason}")
    IO.puts(reason)

    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_uart, _uart_port, data}, state) do
    if is_usage_message(data) do
      MeterReader.WaterTickStore.increment()

      Backends.RedisBackend.store_water_tick()

      Backends.Postgres.Dispatcher.water_tick_received()
    end

    {:noreply, state}
  end

  @doc """
  Determines whether water was actually consumed.

  A message is either "TICK <nnn>" or "USAGE <nnn>".

  TICK is just a clock tick to make it obvious that the detector is
  running. USAGE is an actual registration of water consumption.

  The <nnn> is a number that can be ignored: It is the measured
  reflected amount of light. It is there for in case debugging is
  necessary, e.g. when a new water meter is installed, reflective
  values of the gauge are typically different, so the threshold values
  should change. Having the values in the output makes that a tiny
  bit easier.
  """
  def is_usage_message(message) do
    String.match?(message, ~r[USAGE])
  end
end
