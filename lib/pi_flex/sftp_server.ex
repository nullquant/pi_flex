defmodule PiFlex.SFTPServer do
  @moduledoc "SFTP Server"

  require Logger

  def start do
    # TODO: start the SSH daemon with the SFTP subsystem
    port = Application.get_env(:modbus_server, :ftp_port)
    system_folder = Path.join(System.get_env("HOME"), "sftp_daemon")

    data_folder =
      Path.join(System.get_env("HOME"), Application.get_env(:modbus_server, :ftp_folder))

    if not File.dir?(data_folder) do
      File.mkdir(data_folder)
    end

    opts = [
      {:system_dir, system_folder |> to_charlist},
      {:user_passwords,
       [
         {Application.get_env(:modbus_server, :ftp_user) |> to_charlist,
          Application.get_env(:modbus_server, :ftp_password) |> to_charlist}
       ]},
      {:subsystems, [:ssh_sftpd.subsystem_spec([{:root, data_folder |> to_charlist}])]}
    ]

    res = :ssh.daemon(port, opts)

    Logger.info("(#{__MODULE__}): Starting SFTP server on #{port} port: #{inspect(res)}")
  end
end
