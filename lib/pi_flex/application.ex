defmodule PiFlex.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do

    Logger.info("")
    Logger.info("(#{__MODULE__}): Application starting, version " <> to_string(Application.spec(:pi_flex, :vsn)))

    PiFlex.SFTPServer.start()

    children = [
      PiFlex.Ntp,
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
