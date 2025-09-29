defmodule PiFlex.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("")
    Logger.info("  ____  _           _____ _           ")
    Logger.info(" |  _ \(_)         |  ___| | _____  __")
    Logger.info(" | |_) | |  _____  | |_  | |/ _ \ \/ /")
    Logger.info(" |  __/| | |_____| |  _| | |  __/>  < ")
    Logger.info(" |_|   |_|         |_|   |_|\___/_/\_\\")
    Logger.info("")

    Logger.info(
      "(#{__MODULE__}): Application starting, version " <>
        to_string(Application.spec(:pi_flex, :vsn)) <>
        " " <>
        to_string(Application.spec(:pi_flex, :description))
    )

    PiFlex.SFTPServer.start()

    children = [
      PiFlex.Ntp,
      PiFlex.Update,
      %{
        id: PiFlex.EtsServer,
        start: {PiFlex.EtsServer, :start_link, [0]}
      },
      PiFlex.Supervisor,
      Proxy.Supervisor
    ]

    opts = [strategy: :one_for_one, name: PiFlex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
