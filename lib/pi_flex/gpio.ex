defmodule PiFlex.Gpio do
  @moduledoc """
  Read and write GPIO.
  """
  use GenServer
  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Logger.info("(#{__MODULE__}): GPIO starting")

    board = String.upcase(Application.get_env(:pi_flex, :board_type))

    cond do
      String.contains?(board, "RASP") ->
        {_, 0} =
          System.cmd("raspi-gpio", [
            "set",
            to_string(Application.get_env(:pi_flex, :gpio_stop_pin)),
            "ip",
            "pd"
          ])

        {_, 0} =
          System.cmd("raspi-gpio", [
            "set",
            to_string(Application.get_env(:pi_flex, :gpio_fan_pin)),
            "op",
            "dl"
          ])

      true ->
        {_, 0} =
          System.cmd("gpio", [
            "mode",
            to_string(Application.get_env(:pi_flex, :gpio_stop_pin)),
            "in"
          ])

        {_, 0} =
          System.cmd("gpio", [
            "mode",
            to_string(Application.get_env(:pi_flex, :gpio_stop_pin)),
            "down"
          ])

        {_, 0} =
          System.cmd("gpio", [
            "mode",
            to_string(Application.get_env(:pi_flex, :gpio_fan_pin)),
            "out"
          ])

        {_, 0} =
          System.cmd("gpio", [
            "write",
            to_string(Application.get_env(:pi_flex, :gpio_fan_pin)),
            "0"
          ])
    end

    Process.send_after(self(), :read, 1000)
    {:ok, ""}
  end

  @impl true
  def handle_info(:read, state) do
    # Logger.info("(#{__MODULE__}): Read GPIOs")
    read_gpio(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:write, pin, value}, state) do
    board = String.upcase(Application.get_env(:pi_flex, :board_type))

    cond do
      String.contains?(board, "RASP") ->
        case value do
          1 ->
            {_, 0} =
              System.cmd("raspi-gpio", ["set", to_string(pin), "dh"])

          _ ->
            {_, 0} =
              System.cmd("raspi-gpio", ["set", to_string(pin), "dl"])
        end

      true ->
        {_, 0} =
          System.cmd("gpio", ["write", to_string(pin), to_string(value)])
    end

    {:noreply, state}
  end

  defp read_gpio(_state) do
    Process.send_after(self(), :read, 500)

    board = String.upcase(Application.get_env(:pi_flex, :board_type))

    result =
      cond do
        String.contains?(board, "RASP") ->
          # GPIO 2: level=1 func=INPUT pull=DOWN
          {reply, 0} =
            System.cmd("raspi-gpio", [
              "get",
              to_string(Application.get_env(:pi_flex, :gpio_stop_pin))
            ])

          reply
          |> String.split()
          |> Enum.at(2)
          |> String.split("=")
          |> Enum.at(1)

        true ->
          {result, 0} =
            System.cmd("gpio", [
              "read",
              to_string(Application.get_env(:pi_flex, :gpio_stop_pin))
            ])

          result
      end

    {int_value, _} = Integer.parse(result)

    GenServer.cast(
      PiFlex.EtsServer,
      {:set_integer, Application.get_env(:pi_flex, :gpio_stop_register), int_value}
    )
  end
end
