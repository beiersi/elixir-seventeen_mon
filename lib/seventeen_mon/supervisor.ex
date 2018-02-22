defmodule SeventeenMon.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    import Cachex.Spec
    
    children = [
      worker(Cachex, [ 
        SeventeenMon.cache_name(), 
        [ 
          expiration: expiration(
            default: :timer.hours(6),
            interval: :timer.seconds(30),
            lazy: true
          )
        ] 
      ])
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
