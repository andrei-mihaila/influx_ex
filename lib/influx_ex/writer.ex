defmodule InfluxEx.Writer do
  alias InfluxEx.Connection

  @spec write(map | list(map), String.t, map) :: :ok | {:error, String.t}
  def write(data, db_name, config) when is_list(data) do
    data
    |> Enum.map(&string_for_point/1)
    |> Enum.join("\n")
    |> Connection.write(db_name, config)
  end
  def write(data, db_name, config) do
    string_for_point(data)
    |> Connection.write(db_name, config)
  end

  # Escapes commas (,), equal signs (=) and spaces with \
  defp escape_ces(v) do
    Regex.replace(~r/([,= ])/, "#{v}", "\\\\\\1")
  end

  # Escapes commas (,) and spaces with \
  defp escape_cs(v) do
    Regex.replace(~r/([, ])/, "#{v}", "\\\\\\1")
  end

  # Escapes double quotes (") with \
  defp escape_dc(v) do
    Regex.replace(~r/(["])/, "#{v}", "\\\\\\1")
  end

  @spec string_for_point(map) :: String.t
  defp string_for_point(data = %{measurement: measurement, fields: fields}) do
    tags = data[:tags] || %{}
    time = data[:time]

    fields_string =
      fields
      |> Enum.map(fn {key, val} -> "#{escape_ces(key)}=#{escape_dc(val)}" end)
      |> Enum.join(",")

    tags_strings = Enum.map(tags, fn {key, val} -> "#{escape_ces(key)}=#{escape_ces(val)}" end)

    key = Enum.join([escape_cs(measurement) | tags_strings], ",")

    "#{key} #{fields_string} #{time}"
    |> String.trim()
  end
end
