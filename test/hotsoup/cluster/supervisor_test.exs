defmodule Hotsoup.Cluster.SupervisorTest do
  use ExUnit.Case

  test "Can start 100 differents routers" do
    assert Stream.repeatedly(fn -> Hotsoup.Cluster.Supervisor.start_router end)
           |> Stream.take(100)
           |> Stream.reject(fn(x) -> elem(x, 0) == :ok end)
           |> Enum.count()
           == 0
  end

  test "Can route nodes" do
    {:ok, pid} = Hotsoup.Cluster.Supervisor.start_router
    assert ["42", "[42]", "\"42\""]
           |> Stream.map(&(Hotsoup.Router.route(pid, :jsx.decode(&1))))
           |> Stream.reject(&(&1 == :ok))
           |> Enum.count()
           == 0
  end
end
