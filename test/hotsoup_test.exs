defmodule HotsoupTest do
  use ExUnit.Case
  doctest Hotsoup

  test "Hotsoup is served" do
    assert Application.ensure_started :hotsoup
  end

  test "Can start 100 differents routers" do
    assert (Stream.repeatedly(fn() -> {:ok, _} = Hotsoup.RouterSupervisor.start_router end)
            |> Stream.take(100)
            |> Stream.uniq()
            |> Stream.reject(fn(x) -> elem(x, 0) == :ok end)
            |> Enum.count()
            == 0)
  end

  test "Can route nodes" do
    {:ok, pid} = Hotsoup.RouterSupervisor.start_router
    assert(["42", "[42]", "\"42\""]
           |> Stream.map(&(Hotsoup.Router.route pid, :jsx.decode(&1)))
           |> Stream.reject(fn x -> x == :ok end)
           |> Enum.count()
           == 0)
  end
end
