defmodule SeventeenMonTest do
  use ExUnit.Case
  doctest SeventeenMon

  test "find ip when params is invalid" do
    assert_raise RuntimeError, "ip is invalid!", fn ->
      SeventeenMon.find("")
    end
    assert_raise RuntimeError, "ip is invalid!", fn ->
      SeventeenMon.find("134.256.0.1")
    end
  end

  test "find ip" do
    keys = SeventeenMon.find("192.168.2.0") |> Map.keys
    assert [] == keys -- [:city, :country, :province]
  end

  @tag timeout: 10000000
  test "performance test" do
    IO.puts "\n"
    IO.puts "Testing SeventeenMon.find/1 performance"

    {tc, times} = :timer.tc fn ->
      Enum.reduce (1..2000), 0, fn(_, acc) ->
        ip = Enum.map((0..3), fn(_) ->
          :rand.uniform(255)
        end) |> Enum.join(".")

        SeventeenMon.find(ip)

        acc + 1
      end
    end


    IO.puts "Average execute time: #{tc / times} μs."
  end

end
