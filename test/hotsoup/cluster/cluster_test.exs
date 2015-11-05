defmodule Hotsoup.ClusterTest do
  use ExUnit.Case

  setup do
    {:ok, [count: 100, range: 9000, offset: 1000, max: 10000]}
  end

  test "Can lauch a bunch of routers and wait for them to die", context do
    Process.flag(:trap_exit, true)

    count = context[:count]
    range = context[:range]
    offset = context[:offset]

    routers = Stream.repeatedly(fn -> Hotsoup.Cluster.get_router(%{ttl: trunc(:random.uniform * range) + offset}) end)
              |> Stream.take(count)
              |> Stream.filter_map(fn(x) -> elem(x, 0) == :ok end,
                                   fn({_, pid}) -> pid end)
              |> Enum.to_list
              
    assert Enum.count(routers) == count
  
    Enum.each(routers, &Process.link(&1))
    Stream.repeatedly(fn ->
                        receive do
                          {:EXIT, _pid, _} -> :ok
                        end
                      end)
    |> Enum.take(count)
    
    assert [] == Process.info(self)[:messages]
  end

  test "Route one / get one", context do
    count = context[:count]
    
    routers =  Stream.repeatedly(fn -> Hotsoup.Cluster.get_router(%{ttl: trunc(:random.uniform * context[:range]) + context[:offset]}) end)
               |> Stream.take(count)
               |> Stream.filter_map(&(elem(&1, 0) == :ok),
                                    &(elem(&1, 1)))
               |> Enum.to_list()

    assert Enum.count(routers) == count

    Hotsoup.Cluster.subscribe(self, "42")
    
    jnode = :jsx.decode("42")

    routers
    |> List.first()
    |> Hotsoup.Router.route(jnode)

    assert_receive {^jnode, [{}]}
  end
  
  test "Subscribe once, route N times, receive N times.", context do
    count = context[:count]
    
    {:ok, rid} = Hotsoup.Cluster.get_router
    Hotsoup.Cluster.subscribe(self, "42")
    
    routers =  Stream.repeatedly(fn ->
                                   {:ok, rid} = Hotsoup.Cluster.get_router
                                   rid
                                 end)
               |> Stream.take(count-1)
               |> Enum.to_list
    routers = [rid | routers]

    jnode = :jsx.decode("42")

    Task.start(fn -> Enum.each(routers, &Hotsoup.Router.route(&1, jnode)) end)
    
    Stream.repeatedly(fn ->
                        receive do
                          {^jnode, [{}]} -> :ok
                        end
                      end)
    |> Enum.take(count)
    
    refute_receive {^jnode, [{}]}
  end
end
