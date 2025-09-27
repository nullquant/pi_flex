defmodule PiFlex.Ntp do
  use GenServer

  require Logger

  import Bitwise

  @ntp_port 123
  @client_timeout 500
  # offset yr 1900 to unix epoch
  @epoch 2_208_988_800
  @repeat 3_600_000

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    Logger.info("(#{__MODULE__}): NTP starting")

    Process.send_after(self(), :sync, 100)
    {:ok, %{sync: false}}
  end

  @impl GenServer
  def handle_info(:sync, state) do
    # When the server reply is received, the client determines a
    # Destination Timestamp variable as the time of arrival according to
    # its clock in NTP timestamp format.  The following table summarizes
    # the four timestamps.

    #   Timestamp Name          ID   When Generated
    #   ------------------------------------------------------------
    #   Originate Timestamp     T1   time request sent by client
    #   Receive Timestamp       T2   time request received by server
    #   Transmit Timestamp      T3   time reply sent by server
    #   Destination Timestamp   T4   time reply received by client

    # The roundtrip delay d and system clock offset t are defined as:
    #   d = (T4 - T1) - (T3 - T2)     t = ((T2 - T1) + (T3 - T4)) / 2.

    case net_status() do
      :error ->
        Process.send_after(self(), :sync, 1000)

      :ok ->
        ntp_time = get_time()

        {{year, month, day}, {hours, minutes, seconds}} =
          :calendar.system_time_to_local_time(
            trunc(ntp_time[:transmit_timestamp] * 1_000_000),
            :microsecond
          )

        yy = Integer.to_string(year)
        mth = String.pad_leading(Integer.to_string(month), 2, "0")
        dd = String.pad_leading(Integer.to_string(day), 2, "0")

        hh = String.pad_leading(Integer.to_string(hours), 2, "0")
        mm = String.pad_leading(Integer.to_string(minutes), 2, "0")
        ss = String.pad_leading(Integer.to_string(seconds), 2, "0")

        Logger.info("(#{__MODULE__}): Set time & date: #{yy}-#{mth}-#{dd} #{hh}:#{mm}:#{ss}")

        {message, result} =
          System.cmd("timedatectl", ["set-time", "#{yy}-#{mth}-#{dd} #{hh}:#{mm}:#{ss}"])

        Logger.info("(#{__MODULE__}): system answer: #{inspect({message, result})}")

        Process.send_after(self(), :sync, @repeat)
    end

    {:noreply, state}
  end

  def net_status() do
    case HTTPoison.head("www.yandex.ru") do
      {:ok, _} ->
        Logger.info("(#{__MODULE__}): Internet connection: OK")
        :ok

      {:error, _} ->
        # Logger.error("(#{__MODULE__}): No internet connection!")
        :error
    end
  end

  defp get_time() do
    random_domain = String.to_charlist(Enum.random(ntp_servers()))
    get_time(random_domain)
  end

  defp get_time(ip) do
    ntp_request = create_ntp_request()
    {timestamp, ntp_response} = send_ntp_request(ip, ntp_request)
    process_ntp_response(timestamp, ntp_response)
  end

  defp ntp_servers do
    ["0.ru.pool.ntp.org", "1.ru.pool.ntp.org", "2.ru.pool.ntp.org", "3.ru.pool.ntp.org"]
  end

  defp create_ntp_request do
    <<0::integer-size(2), 4::integer-size(3), 3::integer-size(3), 0::integer-size(376)>>
  end

  def send_ntp_request(ip, ntp_request) do
    {:ok, socket} = :gen_udp.open(0, [:binary, {:active, false}])

    {now_ms, now_s, now_us} = :erlang.timestamp()
    timestamp_now = now_ms * 1.0e6 + now_s + now_us / 1000.0

    :gen_udp.send(socket, ip, @ntp_port, ntp_request)
    {:ok, {_address, _port, response}} = :gen_udp.recv(socket, 0, @client_timeout)
    :gen_udp.close(socket)

    {timestamp_now, response}
  end

  defp process_ntp_response(
         timestamp_send,
         <<li::integer-size(2), version::integer-size(3), mode::integer-size(3),
           stratum::integer-size(8), poll::integer-signed-size(8),
           precision::integer-signed-size(8), root_del::integer-size(32),
           root_disp::integer-size(32), r1::integer-size(8), r2::integer-size(8),
           r3::integer-size(8), r4::integer-size(8), rts_i::integer-size(32),
           rts_f::integer-size(32), ots_i::integer-size(32), ots_f::integer-size(32),
           rcv_i::integer-size(32), rcv_f::integer-size(32), xmt_i::integer-size(32),
           xmt_f::integer-size(32)>>
       ) do
    {now_ms, now_s, now_us} = :erlang.timestamp()
    timestamp_now = now_ms * 1.0e6 + now_s + now_us / 1000.0
    timestamp_transit = xmt_i - @epoch + binfrac(xmt_f)

    %{
      li: li,
      vn: version,
      mode: mode,
      stratum: stratum,
      poll: poll,
      precision: precision,
      root_delay: root_del,
      root_dispersion: root_disp,
      reference_id: {r1, r2, r3, r4},
      reference_timestamp: rts_i - @epoch + binfrac(rts_f),
      originate_timestamp: ots_i - @epoch + binfrac(ots_f),
      receive_timestamp: rcv_i - @epoch + binfrac(rcv_f),
      transmit_timestamp: timestamp_transit,
      client_receive_timestamp: timestamp_now,
      client_send_timestamp: timestamp_send,
      offset: timestamp_transit - timestamp_now
    }
  end

  defp binfrac(bin), do: binfrac(bin, 2, 0)
  defp binfrac(0, _, frac), do: frac
  defp binfrac(bin, n, frac), do: binfrac(bsr(bin, 1), n * 2, frac + band(bin, 1) / n)
end
