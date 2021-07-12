defmodule Veml6030 do
  @moduledoc """
  Documentation for `Veml6030`.
  """
  use GenServer
  require Logger
  alias Veml6030.{Comm, Config}

  def start_link(options \\ %{}) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def measure(pid \\ __MODULE__) do
    GenServer.call(pid, :measure)
  end

  @impl GenServer
  def init(%{address: address, i2c_bus_name: bus_name} = args) do
    i2c = Comm.open(bus_name)

    config =
      args
      |> Map.take([:gain, :int_time, :shutdown, :interrupt])
      |> Config.new()

    Comm.write_config(config, i2c, address)

    :timer.send_interval(1_000, :tick)

    {:ok, %{i2c: i2c, address: address, config: config, last_reading: :no_reading}}
  end

  @impl GenServer
  def init(args) do
    {bus_name, address} = Comm.discover()
    transport = "bus: #{bus_name}, address: #{address}"
    Logger.info("Starting VEML6030. Please specify both an address and a bus.")
    Logger.info("Starting on " <> transport)

    init(
      args
      |> Map.put(:address, address)
      |> Map.put(:i2c_bus_name, bus_name)
    )
  end

  @impl GenServer
  def handle_info(:tick, %{i2c: i2c, address: address, config: config} = state) do
    updated_with_reading = %{state | last_reading: Comm.read(i2c, address, config)}

    {:noreply, updated_with_reading}
  end

  @impl GenServer
  def handle_call(:measure, _from, state) do
    {:reply, state.last_reading, state}
  end
end
