defmodule SeventeenMon do
  use Application

  @cache_name :"seventeen_mon_cache"

  def start(_type, _args) do
    SeventeenMon.Supervisor.start_link(name: SeventeenMon.Supervisor)
  end

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

    data = data()

    tmp_offset = Enum.at(ip_list, 0) * 4

    offset = data_offset(data)
    index = data_index(data, offset)
    max_comp_len = data_max_comp_len(offset)

    << start :: unsigned-little-32 >> = binary_part(index, tmp_offset, 4)
    start = start * 8 + 1024

    {index_offset, index_length} = get_index_offset(start, max_comp_len, index, packed_ip)

    if is_nil(index_offset) or is_nil(index_length) do
      "N/A"
    else

      try do
        result = data_seek(data, offset, index_offset, index_length) 

        %{
          country: Enum.at(result, 0),
          province: Enum.at(result, 1),
          city: Enum.at(result, 2)
        }
      rescue
        _ -> 
          "N/A"
      end

    end
  end

  def cache_name do
    @cache_name
  end

  def data do
    case Cachex.get!(@cache_name, "data") do
      nil ->
        data = File.read!(data_file_path())
        Cachex.put(@cache_name, "data", data)
        data
      data ->
        data
    end
  end

  def data_dir do
    Path.join(~w(#{:code.priv_dir(:seventeen_mon)} data))
  end
  
  def data_file_path do
    Path.join(~w(#{data_dir()} 17monipdb.dat))
  end

  def data_offset(data) do
    case Cachex.get!(@cache_name, "data_offset") do
      nil ->
        << data_offset :: unsigned-32 >> = binary_part(data, 0, 4)
        Cachex.put(@cache_name, "data_offset", data_offset)
        data_offset

      data_offset ->
        data_offset
    end
  end

  def data_index(data, offset) do
    case Cachex.get!(@cache_name, "data_index") do
      nil ->
        data_index = binary_part(data, 4, offset-4)
        Cachex.put(@cache_name, "data_index", data_index)
        data_index

      data_index ->
        data_index

    end
  end

  def data_max_comp_len(offset) do
    offset - 1024 - 4
  end

  def data_seek(data, offset, index_offset, index_length) do
    result = binary_part(data,  offset + index_offset - 1024, index_length)
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
