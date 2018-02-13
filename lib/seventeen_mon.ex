defmodule SeventeenMon do
  @moduledoc """
  Documentation for SeventeenMon.
  """
  
  @root_dir       File.cwd!
  @data_dir       Path.join(~w(#{@root_dir} data))
  @data_file_path Path.join(~w(#{@data_dir} 17monipdb.dat))
  @ets_table_name "#{__MODULE__}:ets_table" |> String.to_atom()

  def ets_table_name do
    @ets_table_name
  end

  def create_est_table do
    case :ets.info(ets_table_name()) do
      :undefined ->
        :ets.new(ets_table_name(), [:named_table])
        ets_table_name()
      ets_tab ->
        ets_tab[:name]
    end
  end

  @doc """
  find ip

  ## Examples

  #iex> SeventeenMon.find("127.0.0.1")
  #    %{country: "country", provice: "provice", city: "city"}

  """
  def find(ip) do
    create_est_table()

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

  def data_fp() do
    case :ets.lookup(ets_table_name(), "fp") do
      [] ->
        fp = File.open!(data_file_path(), [:read, :binary])
        :ets.insert(ets_table_name(), {"fp", fp})
        fp
      [{"fp", fp} | _] ->
        fp
    end
  end
  
  def data_file_path, do: @data_file_path

  def data_offset(fp) do
    case :ets.lookup(ets_table_name(), "offset") do
      [] ->
        :file.position(fp, 0)
        << offset :: unsigned-32 >> = IO.binread(fp, 4)
        :ets.insert(ets_table_name(), {"offset", offset})
        offset
      [{"offset", offset} | _] ->
        offset
    end
  end

  def data_index(fp, offset) do
    case :ets.lookup(ets_table_name(), "index") do
      [] ->
        :file.position(fp, 4)
        index = IO.binread(fp, offset - 4)
        :ets.insert(ets_table_name(), {"index", index})
        index
      [{"index", index} | _] ->
        index
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
