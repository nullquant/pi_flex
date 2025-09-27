defmodule PiFlex.Update do
  use GenServer

  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    Logger.info("(#{__MODULE__}): Update service starting")

    Process.send_after(self(), :sync, 1000)
    {:ok, %{sync: false}}
  end

  @impl GenServer
  def handle_info(:sync, state) do
    case net_status() do
      :error ->
        Process.send_after(self(), :sync, 1000)

      :ok ->
        Logger.info("(#{__MODULE__}): Git Pull")

        {text, error} =
          System.cmd("git", ["-C", "/home/orangepi/pi_flex", "pull"])

        Logger.info("(#{__MODULE__}): Result: " <> "#{inspect({text, error})}")

        case error do
          0 ->
            Process.send_after(
              self(),
              :sync,
              Application.get_env(:pi_flex, :git_check_period)
            )

          _ ->
            Process.send_after(self(), :sync, 10000)
        end
    end

    {:noreply, state}
  end

  def net_status() do
    case HTTPoison.head("www.yandex.ru") do
      {:ok, _} ->
        # Logger.info("(#{__MODULE__}): Internet connection: OK")
        :ok

      {:error, _} ->
        # Logger.error("(#{__MODULE__}): No internet connection!")
        :error
    end
  end
end
