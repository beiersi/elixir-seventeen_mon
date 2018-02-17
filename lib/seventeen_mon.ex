defmodule SeventeenMon do
  @moduledoc """
  Documentation for SeventeenMon.
  """
  
  @doc """
  find ip

  ## Examples

  #iex> SeventeenMon.find("127.0.0.1")
  #    %{country: "country", provice: "provice", city: "city"}

  """
  def find(ip) do
    ip_list = ip_to_list(ip)
    ip_long = ip_to_long(ip_list)
    packed_ip = packed_ip(ip_long)

    data_fp = data_fp()

    tmp_offset = Enum.at(ip_list, 0) * 4

    offset = data_offset(data_fp)
    index = data_index(data_fp, offset)
    max_comp_len = data_max_comp_len(offset)

    << start :: unsigned-little-32 >> = binary_part(index, tmp_offset, 4)
    start = start * 8 + 1024

    {index_offset, index_length} = get_index_offset(start, max_comp_len, index, packed_ip)

    if is_nil(index_offset) or is_nil(index_length) do
      "N/A"
    else

      try do
        result = data_seek(data_fp, offset, index_offset, index_length) 

        %{
          country: Enum.at(result, 0),
          province: Enum.at(result, 1),
          city: Enum.at(result, 2)
        }
      rescue
        _ -> "N/A"
      end

    end
  end

  def data_fp do
    case Process.get(:data_fp, "nil") do
      "nil" ->
        create_data_fp()
      data_fp ->
        if Process.alive?(data_fp) do
          data_fp
        else
          create_data_fp()
        end
    end
  end

  def create_data_fp do
    data_fp = File.open!(data_file_path(), [:read, :binary])
    Process.put(:data_fp, data_fp)
    data_fp
  end


  def data_dir do
    Path.join(~w(#{:code.priv_dir(:seventeen_mon)} data))
  end
  
  def data_file_path do
    Path.join(~w(#{data_dir()} 17monipdb.dat))
  end

  def data_offset(fp) do
    case Process.get(:data_offset, "nil") do
      "nil" ->
        {:ok, << data_offset :: unsigned-32 >>} = :file.pread(fp, 0, 4)
        Process.put(:data_offset, data_offset)
        data_offset
      data_offset ->
        data_offset
    end
  end

  def data_index(fp, offset) do
    case Process.get(:"data_index_#{offset}", "nil") do
      "nil" ->
        {:ok, data_index} = :file.pread(fp, 4, offset - 4)
        Process.put(:"data_index_#{offset}", data_index)
        data_index
      data_index ->
        data_index
    end
  end

  def data_max_comp_len(offset) do
    offset - 1024 - 4
  end

  def data_seek(fp, offset, index_offset, index_length) do
    {:ok, result} = :file.pread(fp, offset + index_offset - 1024, index_length)
    String.split(result, "\t")
  end

  def ip_to_list(ip) do
    ip_list = String.split(ip, ".") 
              |> Enum.map(fn(x) ->
                try do
                  String.to_integer(x) 
                rescue
                  _-> -1
                end
              end)

    if length(ip_list) != 4 or Enum.any?(ip_list, fn(x) -> x < 0 || x > 255 end) do
      raise "ip is invalid!"
    end

    ip_list
  end

  def ip_to_long(ip) when is_list(ip) do
    {_, ip_long} = ip 
                   |> Enum.reverse 
                   |> Enum.with_index 
                   |> Enum.map_reduce(0, fn(x, acc) -> 
                        {elem(x, 0), (elem(x, 0) * :math.pow(2, elem(x, 1) * 8) |> round()) + acc} 
                   end)

    ip_long
  end

  def ip_to_long(ip) when is_bitstring(ip) do
    ip
    |> ip_to_list()
    |> ip_to_long()
  end

  def packed_ip(ip) when is_bitstring(ip) do
    packed_ip(ip_to_long(ip))
  end

  def packed_ip(ip) when is_integer(ip) do
    <<ip :: unsigned-32>>
  end

  def get_index_offset(start, max_comp_len, index, packed_ip) when start < max_comp_len do
    if binary_part(index, start, 4) >= packed_ip do
      << index_offset :: unsigned-little-32 >> = binary_part(index, start + 4, 3) <> "\x00"
      << index_length :: unsigned-8 >> = binary_part(index, start + 7, 1)
      {index_offset, index_length}
    else
      get_index_offset(start + 8, max_comp_len, index, packed_ip)
    end
  end

  def get_index_offset(start, max_comp_len, _index, _packed_ip) when start >= max_comp_len do
    {nil, nil}
  end
end
