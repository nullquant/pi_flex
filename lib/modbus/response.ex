defmodule Modbus.Response do
  @moduledoc false

  # READ RESPONSES
  def pack({:rc, slave, _address, count, _}, values) do
    ^count = Enum.count(values)
    data = Modbus.Crc.bitlist_to_bin(values)
    reads(slave, 1, data)
  end

  def pack({:ri, slave, _address, count, _}, values) do
    ^count = Enum.count(values)
    data = Modbus.Crc.bitlist_to_bin(values)
    reads(slave, 2, data)
  end

  def pack({:rhr, slave, _address, count, _}, values) do
    ^count = Enum.count(values)
    data = Modbus.Crc.reglist_to_bin(values)
    reads(slave, 3, data)
  end

  def pack({:rir, slave, _address, count, _}, values) do
    ^count = Enum.count(values)
    data = Modbus.Crc.reglist_to_bin(values)
    reads(slave, 4, data)
  end

  # WRITE RESPONSES
  def pack({:fc, slave, address, value, _}, nil) when is_integer(value) do
    write(:d, slave, 5, address, value)
  end

  def pack({:phr, slave, address, value, _}, nil) when is_integer(value) do
    write(:a, slave, 6, address, value)
  end

  def pack({:fc, slave, address, values, _}, nil) when is_list(values) do
    writes(:d, slave, 15, address, values)
  end

  def pack({:phr, slave, address, values, _}, nil) when is_list(values) do
    writes(:a, slave, 16, address, values)
  end

  defp reads(slave, function, data) do
    bytes = :erlang.byte_size(data)
    <<slave, function, bytes, data::binary>>
  end

  defp write(:d, slave, function, address, value) do
    <<slave, function, address::16, Modbus.Crc.bool_to_byte(value), 0x00>>
  end

  defp write(:a, slave, function, address, value) do
    <<slave, function, address::16, value::16>>
  end

  defp writes(_type, slave, function, address, values) do
    count = Enum.count(values)
    <<slave, function, address::16, count::16>>
  end

  # ERRORS
  def error({:rc, slave, _address, _value, _}, error_no) do
    <<slave, Bitwise.bor(128, 1), error_no>>
  end

  def error({:ri, slave, _address, _value, _}, error_no) do
    <<slave, Bitwise.bor(128, 2), error_no>>
  end

  def error({:rhr, slave, _address, _value, _}, error_no) do
    <<slave, Bitwise.bor(128, 3), error_no>>
  end

  def error({:rir, slave, _address, _value, _}, error_no) do
    <<slave, Bitwise.bor(128, 4), error_no>>
  end

  def error({:fc, slave, _address, value, _}, error_no) when is_integer(value) do
    <<slave, Bitwise.bor(128, 5), error_no>>
  end

  def error({:phr, slave, _address, value, _}, error_no) when is_integer(value) do
    <<slave, Bitwise.bor(128, 6), error_no>>
  end

  def error({:fc, slave, _address, value, _}, error_no) when is_list(value) do
    <<slave, Bitwise.bor(128, 15), error_no>>
  end

  def error({:phr, slave, _address, value, _}, error_no) when is_list(value) do
    <<slave, Bitwise.bor(128, 16), error_no>>
  end
end
