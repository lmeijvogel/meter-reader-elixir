defmodule MeterReader.P1MessageDecoder do
  alias MeterReader.P1Message

  require Logger

  use GenServer

  @impl true
  def init(message_start_marker) do
    {:ok, %{message: %P1Message{}, message_start_marker: message_start_marker}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def parse_line(line) do
    GenServer.call(__MODULE__, {:parse, line})
  end

  @impl true
  def handle_call({:parse, line}, _from, state) do
    {result, message} = parse_line_int(line, state.message, state.message_start_marker)

    {:reply, result, %{state | message: message}}
  end

  def parse_line_int(line, message, message_start_marker) do
    now = DateTime.now!("Europe/Amsterdam")

    result = P1Message.decode(line, message_start_marker, message, now)

    case result do
      :waiting ->
        {:waiting, message}

      {:added, updated_message} ->
        {:waiting, updated_message}

      {:done, finished_message} ->
        {{:done, finished_message}, %P1Message{}}

      :error ->
        {:error, %P1Message{}}
    end
  end
end
