defmodule PiFlex.FileWriter do
  @moduledoc """
  Read and write data to files.
  """
  use GenServer
  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Logger.info("(#{__MODULE__}): File Writer starting")

    data_folder =
      Path.join(System.get_env("HOME"), Application.get_env(:modbus_server, :ftp_folder))

    if not File.dir?(data_folder) do
      File.mkdir(data_folder)
    end

    files = File.ls!(data_folder)

    if length(files) > Application.get_env(:modbus_server, :max_data_files) do
      files
      |> Enum.sort()
      |> Enum.take(length(files) - Application.get_env(:modbus_server, :max_data_files))
      |> Enum.map(fn x -> Path.join(data_folder, x) end)
      |> Enum.map(fn x -> File.rm!(x) end)
    end

    {:ok, %{folder: data_folder, writed: 0}}
  end

  @impl true
  def handle_cast({:write}, %{folder: data_folder, writed: count} = state) do
    year = get_string_integer(Application.get_env(:modbus_server, :panel_year_register))
    month = get_string_integer(Application.get_env(:modbus_server, :panel_month_register), 2)
    day = get_string_integer(Application.get_env(:modbus_server, :panel_day_register), 2)
    hour = get_string_integer(Application.get_env(:modbus_server, :panel_hour_register), 2)
    min = get_string_integer(Application.get_env(:modbus_server, :panel_min_register), 2)
    sec = get_string_integer(Application.get_env(:modbus_server, :panel_sec_register), 2)
    mil = get_string_integer(Application.get_env(:modbus_server, :panel_mil_register), 3)

    pv = to_string(GenServer.call(PiFlex.EtsServer, {:get_float, 0}))
    sp = to_string(GenServer.call(PiFlex.EtsServer, {:get_float, 2}))
    out = to_string(GenServer.call(PiFlex.EtsServer, {:get_float, 14}))

    s1 = get_string_integer(16)
    s2 = get_string_integer(17)
    panel_state = get_string_integer(18)
    panel_stage = get_string_integer(19)

    i1 =
      to_string(
        GenServer.call(
          PiFlex.EtsServer,
          {:get_float, Application.get_env(:modbus_server, :i1_register)}
        )
      )

    i2 =
      to_string(
        GenServer.call(
          PiFlex.EtsServer,
          {:get_float, Application.get_env(:modbus_server, :i2_register)}
        )
      )

    i3 =
      to_string(
        GenServer.call(
          PiFlex.EtsServer,
          {:get_float, Application.get_env(:modbus_server, :i3_register)}
        )
      )

    fan =
      to_string(
        GenServer.call(
          PiFlex.EtsServer,
          {:get_float, Application.get_env(:modbus_server, :fan_register)}
        )
      )

    stop = get_string_integer(Application.get_env(:modbus_server, :gpio_stop_register))

    datetime = DateTime.to_string(DateTime.add(DateTime.utc_now(), 3, :hour))

    data = [
      year,
      "-",
      month,
      "-",
      day,
      " ",
      hour,
      ":",
      min,
      ":",
      sec,
      ".",
      mil,
      ",",
      String.slice(datetime, 0..22),
      ",",
      pv,
      ",",
      sp,
      ",",
      i1,
      ",",
      i2,
      ",",
      i3,
      ",",
      fan,
      ",",
      out,
      ",",
      s1,
      ",",
      s2,
      ",",
      panel_state,
      ",",
      panel_stage,
      ",",
      stop,
      "\n"
    ]

    # String.slice(datetime, 0..9) <> ".csv"
    filename = year <> "-" <> month <> "-" <> day <> ".csv"

    {:ok, file} = File.open(Path.join(data_folder, filename), [:append])
    IO.binwrite(file, data)
    File.close(file)

    new_count =
      if count > 999 do
        Logger.info("(#{__MODULE__}): Writed #{inspect(count)} lines")
        0
      else
        count + 1
      end

    {:noreply, %{state | writed: new_count}}
  end

  defp get_string_integer(address, pad \\ 1) do
    [value] = GenServer.call(PiFlex.EtsServer, {:read, address, 1})

    to_string(value)
    |> String.pad_leading(pad, "0")
  end
end
