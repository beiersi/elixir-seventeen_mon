Benchee.run(%{
  "find ip" => fn ->
    ip = Enum.map((0..3), fn(_) ->
      :rand.uniform(255)
    end) |> Enum.join(".")

    SeventeenMon.find(ip)
  end
}, time: 5)
