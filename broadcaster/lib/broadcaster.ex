defmodule Broadcaster do
  @moduledoc """
  The `Broadcaster` service is a thin wrapper layer around PubSub `PG2`
  to broadcast messages from devices.  `WARNING:` this service must be used
  behind a firewall! Erlang messages are raw, consider MQTT if using outside
  of a firewall.
  """
  use GenServer
  alias Phoenix.PubSub

  def start_link(args \\ %{}) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def state(pid \\ __MODULE__), do: GenServer.call(pid, :state)

  @impl GenServer
  def init(args) do
    sensors = args[:sensors] || [test_sensor()]
    interval = args[:interval] || 1_000
    pubsub = args[:pubsub] || %{topic: "measurements", server: SensorHub.PubSub}

    :timer.send_interval(interval, :tick)

    {:ok, %{sensors: sensors, pubsub: pubsub, measurements: []}}
  end

  @impl GenServer
  def handle_call(:state, _from, state) do
    {:reply, state.measurements, state}
  end

  @impl GenServer
  def handle_info(:tick, state) do
    {:noreply, state |> measure() |> publish()}
  end

  defp test_sensor do
    %{
      name: :test,
      read: fn -> %{time: Time.utc_now()} end,
      convert: fn x -> x end,
      fields: [:time]
    }
  end

  defp measure(state) do
    measurements =
      for sensor <- state.sensors,
          into: %{},
          do: {sensor.name, sensor.read.() |> sensor.convert.()}

    %{state | measurements: measurements}
  end

  defp publish(%{pubsub: pubsub} = state) do
    PubSub.broadcast(pubsub.server, pubsub.topic, state.measurements)
    state
  end
end
