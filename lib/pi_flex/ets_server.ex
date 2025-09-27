defmodule PiFlex.EtsServer do
  @moduledoc false

  use GenServer
  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Logger.info("(#{__MODULE__}): ETS Server starting")

    table = :ets.new(:modbus_table, [:set, :protected, :named_table])

    # TRM500 registers ("PV" 0, "SP" 2, "SP2" 4, SumSP" 6, "Hyst" 8, U.Lo" 10, "U.Hi" 12, "PPV" 14)
    set_floats([0, 2, 4, 6, 8, 10, 12, 14], [20.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0])

    # TRM500 registers ("inp.F" 16, "di.st" 17, di.rc" 18)
    set_integers([16, 17, 18, 19], [1, 1, 0, 0])

    # CLOUD "ID"
    set_string(
      Application.get_env(:modbus_server, :cloud_id_register),
      Application.get_env(:modbus_server, :cloud_id),
      18,
      :modbus
    )

    # CLOUD "Token"
    set_string(
      Application.get_env(:modbus_server, :cloud_token_register),
      Application.get_env(:modbus_server, :cloud_token),
      16,
      :modbus
    )

    # Panel Time
    set_integer(Application.get_env(:modbus_server, :panel_year_register), 0)
    set_integer(Application.get_env(:modbus_server, :panel_month_register), 0)
    set_integer(Application.get_env(:modbus_server, :panel_day_register), 0)
    set_integer(Application.get_env(:modbus_server, :panel_hour_register), 0)
    set_integer(Application.get_env(:modbus_server, :panel_min_register), 0)
    set_integer(Application.get_env(:modbus_server, :panel_sec_register), 0)
    set_integer(Application.get_env(:modbus_server, :panel_mil_register), 0)

    # Currents and fan
    set_float(Application.get_env(:modbus_server, :i1_register), 0.0)
    set_float(Application.get_env(:modbus_server, :i2_register), 0.0)
    set_float(Application.get_env(:modbus_server, :i3_register), 0.0)
    set_float(Application.get_env(:modbus_server, :fan_register), 0.0)

    # Control registers
    # CLOUD_ON
    set_integer(Application.get_env(:modbus_server, :cloud_on_register), 0)
    # WiFi_ERROR
    set_integer(Application.get_env(:modbus_server, :wifi_error_register), 0)
    # WiFi_IP
    set_string(Application.get_env(:modbus_server, :wifi_ip_register), "", 16)
    # PANEL_IP
    set_string(Application.get_env(:modbus_server, :panel_ip_register), "", 16)

    # WiFi_SSIDs
    set_string(Application.get_env(:modbus_server, :wifi_ssid1_register), "", 32)
    set_string(Application.get_env(:modbus_server, :wifi_ssid2_register), "", 32)
    set_string(Application.get_env(:modbus_server, :wifi_ssid3_register), "", 32)
    set_string(Application.get_env(:modbus_server, :wifi_ssid4_register), "", 32)
    set_string(Application.get_env(:modbus_server, :wifi_ssid5_register), "", 32)
    set_string(Application.get_env(:modbus_server, :wifi_ssid6_register), "", 32)
    set_string(Application.get_env(:modbus_server, :wifi_ssid7_register), "", 32)
    set_string(Application.get_env(:modbus_server, :wifi_ssid8_register), "", 32)

    # GPIO
    set_integer(Application.get_env(:modbus_server, :gpio_stop_register), 0)
    set_integer(Application.get_env(:modbus_server, :gpio_fan_register), 0)

    Logger.info("(#{__MODULE__}): EtsServer: initialization")
    {:ok, %{data: table}}
  end

  @impl true
  def handle_cast({:write, write_request}, state) do
    {_, _, address, data, _} = write_request
    # Logger.info("EtsServer: Write #{inspect(data)} to address #{address}")
    write_values(address, data)
    {:noreply, state}
  end

  def handle_cast({:set_string, address, data, len}, state) do
    # Logger.info("EtsServer: Set string #{inspect(data)} to address #{address}")
    set_string(address, data, len)
    {:noreply, state}
  end

  def handle_cast({:set_modbus_string, address, data, len}, state) do
    # Logger.info("EtsServer: Set modbus string #{inspect(data)} to address #{address}")
    set_string(address, data, len, :modbus)
    {:noreply, state}
  end

  def handle_cast({:set_float, address, value}, state) do
    # Logger.info("EtsServer: Set float #{inspect(value)} to address #{address}")
    set_float(address, value)
    {:noreply, state}
  end

  def handle_cast({:set_integer, address, value}, state) do
    # Logger.info("EtsServer: Set integer #{inspect(value)} to address #{address}")
    set_integer(address, value)
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_float, address}, _from, state) do
    reply =
      case check_request(address, 2) do
        true ->
          [{_, w1}] = :ets.lookup(:modbus_table, address)
          [{_, w0}] = :ets.lookup(:modbus_table, address + 1)
          Modbus.IEEE754.from_2_regs(w0, w1, :be)

        false ->
          :error
      end

    {:reply, reply, state}
  end

  def handle_call({:read, address, len}, _from, state) do
    # Logger.info("EtsServer: Read from address #{address}:#{len}")

    reply =
      case check_request(address, len) do
        true ->
          address_end = address + len - 1

          Enum.map(address..address_end, fn i ->
            [{_, value}] = :ets.lookup(:modbus_table, i)
            value
          end)

        false ->
          :error
      end

    {:reply, reply, state}
  end

  defp check_request(address, len) do
    address_end = address + len - 1

    Enum.all?(address..address_end, fn i ->
      :ets.lookup(:modbus_table, i) != []
    end)
  end

  # write list of values to registers
  defp write_values(address, values) do
    len = length(values)
    address_end = address + len

    ^address_end =
      Enum.reduce(values, address, fn value, i ->
        :ets.insert(:modbus_table, {i, value})
        i + 1
      end)
  end

  defp set_floats([], []) do
  end

  defp set_floats([address | address_list], [value | value_list]) do
    set_float(address, value)
    set_floats(address_list, value_list)
  end

  defp set_float(address, value) do
    [w0, w1] = Modbus.IEEE754.to_2_regs(value, :be)
    :ets.insert(:modbus_table, {address, w1})
    :ets.insert(:modbus_table, {address + 1, w0})
  end

  defp set_integers([], []) do
  end

  defp set_integers([address | address_list], [value | value_list]) do
    set_integer(address, value)
    set_integers(address_list, value_list)
  end

  defp set_integer(address, value) do
    :ets.insert(:modbus_table, {address, value})
  end

  defp set_string(address, string, len, type \\ :simple) do
    values_list =
      case type do
        :modbus ->
          rotated = rotate_bytes([], to_charlist(string))

          rotated
          |> Enum.reverse()
          |> Stream.concat(Stream.repeatedly(fn -> 0 end))
          |> Enum.take(len)

        _ ->
          string
          |> to_charlist()
          |> Stream.concat(Stream.repeatedly(fn -> 0 end))
          |> Enum.take(len)
      end

    write_values(address, values_list)
  end

  defp rotate_bytes([], []) do
    []
  end

  defp rotate_bytes(list, [byte | []]) do
    <<value::16>> = <<0::8, byte::8>>
    [value | list]
  end

  defp rotate_bytes(list, [byte0, byte1 | []]) do
    <<value::16>> = <<byte1::8, byte0::8>>
    [value | list]
  end

  defp rotate_bytes(list, [byte0, byte1 | tail]) do
    <<value::16>> = <<byte1::8, byte0::8>>
    rotate_bytes([value | list], tail)
  end
end
