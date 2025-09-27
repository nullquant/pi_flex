defmodule Modbus.Tcp do
  @moduledoc """
  Tcp message helper, functions that handles TCP responses/requests messages.
  """
  require Logger

  def parse(slave, role, data) do
    case Modbus.Tcp.parse_request(data) do
      {:error, _transid} ->
        # bad message
        :none

      {modbus_request, transid} ->
        # Logger.debug(
        #  "(#{__MODULE__}) Received Modbus request: #{inspect({transid, modbus_request})}"
        # )

        {cmd, msg_slave, address, count, operation} = modbus_request

        cond do
          slave != msg_slave ->
            # nothing to do
            :none

          operation == :read ->
            case cmd do
              n when n in [:rhr, :rir] ->
                # read -> read and send reply to client
                case GenServer.call(PiFlex.EtsServer, {:read, address, count}) do
                  :error ->
                    # reply to client with error
                    {:error, Modbus.Tcp.pack_error(modbus_request, 2, transid)}

                  data ->
                    # replay answer with data to client
                    {:reply, Modbus.Tcp.pack_response(modbus_request, data, transid)}
                end

              _ ->
                # implement if server has coils
                # reply to client with error
                {:error, Modbus.Tcp.pack_error(modbus_request, 2, transid)}
            end

          operation == role ->
            case cmd do
              :phr ->
                GenServer.cast(PiFlex.EtsServer, {:write, modbus_request})
                # reply to client with answer
                {:reply, Modbus.Tcp.pack_response(modbus_request, data, transid)}

              _ ->
                # implement if server has coils
                # reply to client with error
                {:error, Modbus.Tcp.pack_error(modbus_request, 2, transid)}
            end
        end
    end
  end

  # REQUESTS
  def parse_request(<<transid::16, protocol_hi, protocol_lo, size::16, payload::binary>> = msg) do
    payload_size = :erlang.byte_size(payload)

    data =
      cond do
        {protocol_hi, protocol_lo} != {0, 0} ->
          Logger.warning("(#{__MODULE__}): protocol mismatch #{inspect(msg, base: :hex)}")

          :error

        size != payload_size ->
          Logger.warning("(#{__MODULE__}): size mismatch #{inspect(msg, base: :hex)}")

          :error

        true ->
          Modbus.Request.parse(payload)
      end

    {data, transid}
  end

  def parse_request(<<transid::16, _payload::binary>> = msg) do
    Logger.warning("(#{__MODULE__}): bad message #{inspect(msg, base: :hex)}")
    {:error, transid}
  end

  def parse_request(short_msg) do
    Logger.warning("(#{__MODULE__}): message too short #{inspect(short_msg, base: :hex)}")
    {:error, 0}
  end

  # RESPONSES
  def pack_response(cmd, values, transid) do
    cmd |> Modbus.Response.pack(values) |> wrap(transid)
  end

  # ERRORS
  def pack_error(cmd, error_no, transid) do
    cmd |> Modbus.Response.error(error_no) |> wrap(transid)
  end

  defp wrap(payload, transid) do
    size = :erlang.byte_size(payload)
    <<transid::16, 0, 0, size::16, payload::binary>>
  end
end
