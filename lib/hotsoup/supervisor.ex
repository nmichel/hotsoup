defmodule Hotsoup.Supervisor do
  use Supervisor
  use Hotsoup.Logger

  # API

  def start_link do
    Supervisor.start_link __MODULE__, []
  end

  # Callbacks Supervisor
  
  def init([]) do
    Hotsoup.Logger.info ["started"]

    [] 
    |> addchild(:supervisor, Hotsoup.RouterManager, [])
    |> supervise(strategy: :one_for_one)
  end

  # Internal

  defp addchild(acc, :supervisor, mod, args, options \\ []) do
    [supervisor(mod, args, options) | acc]
  end
end
