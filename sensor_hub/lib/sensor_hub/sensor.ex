defmodule SensorHub.Sensor do
  defstruct [:name, :fields, :read, :convert]

  def new(name) do
    %__MODULE__{
      read: read_fn(name),
      convert: convert_fn(name),
      fields: fields(name),
      name: name
    }
  end

  def measure(sensor) do
    sensor.read.() |> sensor.convert.()
  end

  defp fields(SGP30), do: [:co2_eq_ppm, :tvoc_ppb]
  defp fields(BMP280), do: [:altitude_m, :pressure_pa, :temperature_c]
  defp fields(VEML6030), do: [:light_in_lumens]

  defp read_fn(SGP30), do: fn -> SGP30.state() end
  defp read_fn(BMP280), do: fn -> BMP280.measure(BMP280) end
  defp read_fn(VEML6030), do: fn -> Veml6030.measure() end

  defp convert_fn(SGP30) do
    fn reading ->
      Map.take(reading, [:co2_eq_ppm, :tvoc_ppb])
    end
  end

  defp convert_fn(BMP280) do
    fn reading ->
      case reading do
        {:ok, measurement} ->
          Map.take(measurement, [:altitude_m, :pressure_pa, :temperature_c])

        _ ->
          %{}
      end
    end
  end

  defp convert_fn(VEML6030) do
    fn data -> %{light_in_lumens: data} end
  end
end
