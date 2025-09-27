defmodule Proxy.PanelProxy do
  @moduledoc """
  Connect to panel, send data to it, reply to Proxy.ServerProxy
  """
  use GenServer
  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Logger.info("(#{__MODULE__}): Panel Proxy starting")

    port = Application.get_env(:modbus_server, :proxy_panel_port)

    {:ok, %{port: port, socket: nil}}
  end

  @impl true
  def handle_cast({:connected}, %{socket: socket, port: port} = state) do
    connected_socket =
      case socket do
        nil ->
          ip = read_panel_ip()
          opts = [:binary, active: true]
          {:ok, connected_socket} = :gen_tcp.connect(ip, port, opts)
          Logger.info("(#{__MODULE__}): PP connects to panel at #{inspect(ip)}:#{inspect(port)}")

          connected_socket

        _ ->
          socket
      end

    {:noreply, %{state | socket: connected_socket}}
  end

  @impl true
  def handle_cast({:data, data}, %{socket: socket, port: port} = state) do
    connected_socket =
      case socket do
        nil ->
          ip = read_panel_ip()
          opts = [:binary, active: true]
          {:ok, connected_socket} = :gen_tcp.connect(ip, port, opts)
          Logger.info("(#{__MODULE__}): PP connects to panel at #{inspect(ip)}:#{inspect(port)}")
          connected_socket

        _ ->
          socket
      end

    # Logger.info("(#{__MODULE__}): PP got from TI #{inspect(data)}, sends to panel")
    :ok = :gen_tcp.send(connected_socket, data)
    {:noreply, %{state | socket: connected_socket}}
  end

  @impl true
  def handle_info({:tcp, _, data}, state) do
    # Logger.info("(#{__MODULE__}): PP got from panel #{inspect(data)}, sends to TI")
    [{pid, nil}] = Registry.lookup(ProxyRegistry, "ServerProxy")
    GenServer.cast(pid, {:panel_send, data})
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _}, state), do: {:stop, :normal, state}
  @impl true
  def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}

  defp read_panel_ip() do
    ip_list =
      GenServer.call(
        PiFlex.EtsServer,
        {:read, Application.get_env(:modbus_server, :panel_ip_register), 16}
      )
      |> List.to_string()
      |> String.trim(<<0>>)
      |> String.split(".")

    case length(ip_list) do
      4 ->
        ip_list
        |> Enum.map(&String.to_integer/1)
        |> List.to_tuple()

      _ ->
        nil
    end
  end
end
