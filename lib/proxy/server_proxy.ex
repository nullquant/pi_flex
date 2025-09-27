defmodule Proxy.ServerProxy do
  @moduledoc """
  Server that can be connected from outside, send info to panel through Proxy.PanelProxy and write back
  """
  require Logger
  use ThousandIsland.Handler

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    Logger.info("(#{__MODULE__}): Proxy Server connecting")

    {:ok, {remote_address, port}} = ThousandIsland.Socket.peername(socket)
    {:ok, _pid} = Registry.register(ProxyRegistry, "ServerProxy", nil)

    Logger.info(
      "(#{__MODULE__}): TI got connected from #{inspect(remote_address)} on port #{port})}"
    )

    GenServer.cast(Proxy.PanelProxy, {:connected})
    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, _socket, state) do
    # send data to panel
    # Logger.info("(#{__MODULE__}): TI got from outside #{inspect(data)}, sends to PP")
    GenServer.cast(Proxy.PanelProxy, {:data, data})
    {:continue, state}
  end

  @impl GenServer
  def handle_cast({:panel_send, msg}, {socket, state}) do
    # send msg from panel back
    # Logger.info("(#{__MODULE__}): TI got from PP #{inspect(msg)}, sends to panel")
    ThousandIsland.Socket.send(socket, msg)
    {:noreply, {socket, state}, socket.read_timeout}
  end
end
