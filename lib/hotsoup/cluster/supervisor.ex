defmodule Hotsoup.Cluster.Supervisor do
  use Supervisor
  use Hotsoup.Logger

  # API

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end
  
  def start_router(opts \\ Hotsoup.Router.default_options) do
    Hotsoup.Logger.info(["start_router"])
    
    Supervisor.start_child(__MODULE__, [opts])
  end

  # Callbacks Supervisor

  def init([]) do
    Hotsoup.Logger.info(["started"])

    [] 
    |> addchild(:worker, Hotsoup.Router, [], [restart: :temporary])
    |> supervise([strategy: :simple_one_for_one])
  end

  defp addchild(acc, :worker, mod, args, options \\ []) do
    [worker(mod, args, options) | acc]
  end
end
