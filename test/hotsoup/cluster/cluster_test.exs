defmodule Hotsoup.ClusterTest do
  use ExUnit.Case
  require Helper

  setup do
    {:ok, [count: 1000, range: 9000, offset: 1000, max: 10000]}
  end

  @tag timeout: 100000
  test "Can lauch a bunch of routers and wait for them to die", context do
    Process.flag(:trap_exit, true)

    count = context[:count]
    range = context[:range]
    offset = context[:offset]
    max = range + offset

    assert(Stream.repeatedly(fn () -> Hotsoup.Cluster.get_router(%{ttl: trunc(:random.uniform * range) + offset}) end)
           |> Stream.take(count)
           |> Stream.reject(fn({:ok, _}) -> false
                              (_) -> true 
                            end)
           |> Enum.count()
           == count)
    
    Helper.wait(max)
    assert({:ok, []} == Hotsoup.Cluster.get_stats(:routers))
  end

  defmodule Client do
    def start(count, master) do
      Task.start(fn() -> loop(count, master) end)
    end

    def loop(0, master) do
      send(master, :done)
    end
    def loop(count, master) do
      receive do
        _ ->
          loop(count-1, master)
      end
    end
  end

  @tag timeout: 100000
  test "Route one / get many", context do
    routers = 
      Stream.repeatedly(fn () -> Hotsoup.Cluster.get_router(%{ttl: trunc(:random.uniform * context[:range]) + context[:offset]}) end)
      |> Stream.take(context[:count])
      |> Stream.reject(fn({:ok, _}) -> false
                         (_) -> true 
                       end)
      |> Stream.map(fn({_, pid}) -> pid end)
      |> Enum.to_list()
      
    {:ok, client_pid} = Client.start(Enum.count(routers), self)
    
    Hotsoup.Cluster.subscribe(client_pid, "42")

    routers
    |> List.first()
    |> Hotsoup.Router.route(:jsx.decode("42"))

    Helper.wait_for_msg()
  end
end
