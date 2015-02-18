defmodule Hotsoup.Supervisor do
  use Supervisor
  use Hotsoup.Logger

  # API

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  # Callbacks Supervisor
  
  def init([]) do
    Hotsoup.Logger.info(["started"])
    
    [] 
    |> addchild(:supervisor, Hotsoup.Cluster.Supervisor, [])
    |> addchild(:worker, Hotsoup.Cluster, [])
    |> supervise([strategy: :one_for_one])
  end

  # Internal

  defp addchild(acc, role, mod, args) do
    addchild(acc, role, mod, args, [])
  end

  defp addchild(acc, :supervisor, mod, args, options) do
    [supervisor(mod, args, options) | acc]
  end
  
  defp addchild(acc, :worker, mod, args, options) do
    [worker(mod, args, options) | acc]
  end
end
