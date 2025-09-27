defmodule PiFlex.Supervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    Logger.info("(#{__MODULE__}): Supervisor starting")

    eth0 = Application.get_env(:pi_flex, :eth0_iface)

    eth0_ip = Modbus.Crc.get_ip(eth0)
    eth0_port = Application.get_env(:pi_flex, :eth0_port)

    ti_child =
      case eth0_ip do
        nil ->
          Logger.info(
            "(#{__MODULE__}): Interface #{eth0} is not initialized, panel is not connected: no ip"
          )

          []

        value ->
          Logger.info("(#{__MODULE__}): Listening from panel on #{eth0_ip}:#{eth0_port}")

          eth0_ip_tuple =
            value
            |> String.split(".")
            |> Enum.map(&String.to_integer/1)
            |> List.to_tuple()

          {ThousandIsland,
           port: eth0_port,
           handler_module: PiFlex.PanelHandler,
           transport_options: [ip: eth0_ip_tuple]}
      end

    children =
      [
        %{
          id: PiFlex.CloudClient,
          start: {PiFlex.CloudClient, :start_link, [0]}
        },
        %{
          id: PiFlex.FileWriter,
          start: {PiFlex.FileWriter, :start_link, [0]}
        },
        %{
          id: PiFlex.Wifi,
          start: {PiFlex.Wifi, :start_link, [0]}
        },
        %{
          id: PiFlex.Gpio,
          start: {PiFlex.Gpio, :start_link, [0]}
        }
      ] ++ [ti_child]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
