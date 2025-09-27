defmodule Proxy.Supervisor do
  @moduledoc false

  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    Logger.info("(#{__MODULE__}): Proxy Supervisor starting")

    # proxy_ip = Modbus.Crc.get_ip(Application.get_env(:modbus_server, :proxy_iface))
    proxy_pi_port = Application.get_env(:modbus_server, :proxy_pi_port)

    # proxy_ip_tuple =
    #  proxy_ip
    #  |> String.split(".")
    #  |> Enum.map(&String.to_integer/1)
    #  |> List.to_tuple()

    # Logger.info("(#{__MODULE__}): Listening outside on #{proxy_ip}:#{proxy_pi_port}")
    Logger.info("(#{__MODULE__}): Listening on port #{proxy_pi_port}")

    children = [
      {Registry, [keys: :unique, name: ProxyRegistry]},
      %{
        id: Proxy.PanelProxy,
        start: {Proxy.PanelProxy, :start_link, [0]}
      },
      {ThousandIsland,
       port: proxy_pi_port,
       handler_module: Proxy.ServerProxy,
       transport_options: [
         mode: :binary,
         send_timeout: 2_000,
         send_timeout_close: true
         # ip: proxy_ip_tuple
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
