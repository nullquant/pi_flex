defmodule Modbus.Request do
  @moduledoc false

  require Logger

  def parse(<<slave, 1, address::16, count::16>>) do
    {:rc, slave, address, count, :read}
  end

  def parse(<<slave, 2, address::16, count::16>>) do
    {:ri, slave, address, count, :read}
  end

  def parse(<<slave, 3, address::16, count::16>>) do
    {:rhr, slave, address, count, :read}
  end

  def parse(<<slave, 4, address::16, count::16>>) do
    {:rir, slave, address, count, :read}
  end

  def parse(<<slave, 5, address::16, 0x00, 0x00>>) do
    {:fc, slave, address, 0, :write}
  end

  def parse(<<slave, 5, address::16, 0xFF, 0x00>>) do
    {:fc, slave, address, 1, :write}
  end

  def parse(<<slave, 6, address::16, value::16>>) do
    {:phr, slave, address, value, :write}
  end

  def parse(<<slave, 15, address::16, count::16, bytes, data::binary>>) do
    ^bytes = Modbus.Crc.byte_count(count)
    values = Modbus.Crc.bin_to_bitlist(count, data)
    {:fc, slave, address, values, :write}
  end

  def parse(<<slave, 16, address::16, count::16, bytes, data::binary>>) do
    ^bytes = 2 * count
    values = Modbus.Crc.bin_to_reglist(count, data)
    {:phr, slave, address, values, :write}
  end

  def parse(bad_msg) do
    Logger.warning("(#{__MODULE__}): Modbus can't decrypt #{inspect(bad_msg, base: :hex)}")
    :error
  end
end
