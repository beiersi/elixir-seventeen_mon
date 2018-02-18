# SeventeenMon 

elixir for ipip.net IP库解析代码。

## Installation

by adding `seventeen_mon` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    ...
    {:seventeen_mon, github: "beiersi/elixir-seventeen_mon", branch: "master"}
    ...
  ]
end
```

## Useage

```elixir
SeventeenMon.find("192.168.2.100")
```

