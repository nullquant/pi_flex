defmodule PiFlex.Wifi do
  @moduledoc """
  Read WiFi SSISs and store them in ETS.
  """
  use GenServer
  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Logger.info("(#{__MODULE__}): WiFi starting")

    Process.send_after(self(), :read, 1000)
    {:ok, %{connected: [], ssid: [], ip: ""}}
  end

  @impl true
  def handle_info(:read, state) do
    # Logger.info("(#{__MODULE__}): Read WiFi SSIDs")
    state = wifi_scan(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:disconnect}, %{connected: connected} = state) do
    if connected != [] do
      {message, result} = System.cmd("nmcli", ["device", "disconnect", "wlan0"])

      case result do
        0 ->
          Logger.info("(#{__MODULE__}): Disconnect from WiFi")

          GenServer.cast(
            PiFlex.EtsServer,
            {:set_string, Application.get_env(:pi_flex, :wifi_ip_register), "", 16}
          )

        value ->
          Logger.info(
            "(#{__MODULE__}): Disconnect from WiFi failed: {#{inspect(message)}, #{inspect(value)}}"
          )
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:connect, ssid, password}, %{connected: connected} = state) do
    if connected == [] do
      Logger.info("(#{__MODULE__}): Connect to WiFi #{ssid}...")

      {message, result} =
        System.cmd("nmcli", [
          "-w",
          "15",
          "device",
          "wifi",
          "connect",
          ssid,
          "password",
          password
        ])

      error =
        if result != 0 || String.contains?(String.downcase(message), "error") do
          Logger.info("(#{__MODULE__}):      ...connection error.")
          1
        else
          Logger.info("(#{__MODULE__}):      ...success.")
          0
        end

      GenServer.cast(
        PiFlex.EtsServer,
        {:set_integer, Application.get_env(:pi_flex, :wifi_error_register), error}
      )
    end

    {:noreply, state}
  end

  defp wifi_scan(state) do
    Process.send_after(self(), :read, 5000)

    {result, 0} = System.cmd("nmcli", ["-t", "device", "wifi"])

    connected =
      result
      |> String.split("\n")
      |> Enum.filter(fn s -> String.at(s, 0) == "*" end)
      |> Enum.map(fn s -> s |> String.split(":") |> Enum.at(7) end)

    not_connected =
      result
      |> String.split("\n")
      |> Enum.filter(fn s -> String.at(s, 0) != "*" end)
      |> Enum.map(fn s -> s |> String.split(":") |> Enum.at(7) end)
      |> Enum.filter(fn s -> s != "" and s != nil end)
      |> Enum.uniq()

    ip =
      case connected do
        [] ->
          ""

        _ ->
          Modbus.Crc.get_ip("wlan0")
      end

    GenServer.cast(
      PiFlex.EtsServer,
      {:set_string, Application.get_env(:pi_flex, :wifi_ip_register), ip, 16}
    )

    [connected | not_connected]
    |> List.flatten()
    |> Enum.uniq()
    |> Stream.concat(Stream.repeatedly(fn -> "" end))
    |> Enum.take(8)
    |> write_ssids()

    %{state | connected: connected, ssid: not_connected, ip: ip}
  end

  defp write_ssids([ssid1, ssid2, ssid3, ssid4, ssid5, ssid6, ssid7, ssid8]) do
    GenServer.cast(
      PiFlex.EtsServer,
      {:set_string, Application.get_env(:pi_flex, :wifi_ssid1_register), ssid1, 16}
    )

    GenServer.cast(
      PiFlex.EtsServer,
      {:set_string, Application.get_env(:pi_flex, :wifi_ssid2_register), ssid2, 16}
    )

    GenServer.cast(
      PiFlex.EtsServer,
      {:set_string, Application.get_env(:pi_flex, :wifi_ssid3_register), ssid3, 16}
    )

    GenServer.cast(
      PiFlex.EtsServer,
      {:set_string, Application.get_env(:pi_flex, :wifi_ssid4_register), ssid4, 16}
    )

    GenServer.cast(
      PiFlex.EtsServer,
      {:set_string, Application.get_env(:pi_flex, :wifi_ssid5_register), ssid5, 16}
    )

    GenServer.cast(
      PiFlex.EtsServer,
      {:set_string, Application.get_env(:pi_flex, :wifi_ssid6_register), ssid6, 16}
    )

    GenServer.cast(
      PiFlex.EtsServer,
      {:set_string, Application.get_env(:pi_flex, :wifi_ssid7_register), ssid7, 16}
    )

    GenServer.cast(
      PiFlex.EtsServer,
      {:set_string, Application.get_env(:pi_flex, :wifi_ssid8_register), ssid8, 16}
    )
  end
end
