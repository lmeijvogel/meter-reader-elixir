defmodule Backends.Mysql.Dispatcher do
  require Logger
  use GenServer

  @moduledoc """
  This module is responsible for receiving all data that is sent to us - Water and P1 energy - and
  sending it to the various backends.

  SolarEdge data does not go through this module.

  The permanent data is stored at intervals to not fill up the data stores too quickly.

  To do this, it keeps the latest P1 message -- its data is cumulative. The latest message
  is then sent to the backends.

  For SQL, the current water "tick" is retrieved and is sent along with the P1 data.
  """

  @impl true
  def init(opts) do
    state = %{
      save_interval_in_seconds: opts[:save_interval_in_seconds]
    }

    if opts[:start] do
      schedule_next_mysql_save(state)
    end

    {:ok, state}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def handle_info(:save_to_mysql, state) do
    schedule_next_mysql_save(state)

    MeterReader.P1MessageStore.with_latest_message(
      &Backends.Mysql.Backend.save(&1, MeterReader.WaterTickStore.get()),
      fn -> Logger.warning("Mysql.Dispatcher: No P1 message in store") end
    )

    {:noreply, state}
  end

  def schedule_next_mysql_save(state) do
    MeterReader.Scheduler.schedule_next(
      {self(), :save_to_mysql},
      "Mysql.Dispatcher",
      {state[:save_interval_in_seconds]}
    )
  end
end
