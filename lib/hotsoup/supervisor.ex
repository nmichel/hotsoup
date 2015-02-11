defmodule Hotsoup.Supervisor do
  use Supervisor
  use Hotsoup.Logger

  def start_link do
    Supervisor.start_link __MODULE__, []
  end

  def init([]) do
    Hotsoup.Logger.info ["started"]

    [] 
    |> addchild(Hotsoup.Router, [])
    |> supervise(strategy: :one_for_one)
  end

  defp addchild(acc, mod, args) do
    [worker(mod, args) | acc]
  end
end
