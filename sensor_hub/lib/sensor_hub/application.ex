defmodule SensorHub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias SensorHub.Sensor

  def start(_type, _args) do
    System.cmd("epmd", ["-daemon"])
    [:hostname, host_name] = Application.get_env(:mdns_lite, :host)
    Node.start(:"hub@#{host_name}.local")

    opts = [strategy: :one_for_one, name: SensorHub.Supervisor]

    children = [] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  def children(:host) do
    []
  end

  def children(_target) do
    [
      {SGP30, []},
      {BMP280, [i2c_address: 0x77, name: BMP280]},
      {Veml6030, %{}},
      broadcaster(),
      {Phoenix.PubSub.Supervisor, [name: SensorHub.PubSub]}
    ]
  end

  def target() do
    Application.get_env(:sensor_hub, :target)
  end

  # Pub/Sub broadcasting config
  defp sensors do
    [Sensor.new(BMP280), Sensor.new(VEML6030), Sensor.new(SGP30)]
  end

  defp broadcaster_pubsub do
    %{topic: "measurements", server: SensorHub.PubSub}
  end

  defp broadcaster do
    {Broadcaster, %{sensors: sensors(), pubsub: broadcaster_pubsub()}}
  end
end
