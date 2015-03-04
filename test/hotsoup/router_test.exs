defmodule Hotsoup.RouterTest do
  use ExUnit.Case

  setup do
    {:ok, rid} = Hotsoup.Router.start_link
    {:ok, [rid: rid]}
  end

  test "Can subscribe listener", %{rid: rid} do
    jnode = :jsx.decode("42")

    Hotsoup.Router.subscribe(rid, "42", self)
    Hotsoup.Router.route(rid, jnode)
    assert_receive {^jnode, [{}]}
  end

  test "Can unsubscribe listener", %{rid: rid} do
    jnode = :jsx.decode("42")
    
    Hotsoup.Router.subscribe(rid, "42", self)
    Hotsoup.Router.route(rid, jnode)
    assert_receive {^jnode, [{}]}
    
    Hotsoup.Router.unsubscribe(rid, self)
    Hotsoup.Router.route(rid, jnode)
    refute_receive {^jnode, [{}]}
  end

  test "Subscribe n times (same process), route once. Get ONCE", %{rid: rid} do
    jnode = :jsx.decode("42")
    count = 100

    Stream.repeatedly(fn -> Hotsoup.Router.subscribe(rid, "42", self) end)
    |> Enum.take(count)
  
    Hotsoup.Router.route(rid, jnode)
    
    assert_receive {^jnode, [{}]}
  end

  test "Subscribe n times (different processes), route once. Get n times", %{rid: rid} do
    jnode = :jsx.decode("42")
    count = 100
    master = self
    
    Stream.repeatedly(fn -> Task.start(fn ->
                                         Hotsoup.Router.subscribe(rid, "42", self)
                                         send(master, :ready)
                                         receive do
                                           r = {^jnode, _} ->
                                             send(master, r)
                                         end
                                       end)
                      end)
    |> Enum.take(count)
  
    Stream.repeatedly(fn ->
                        receive do
                          :ready -> :ok
                        end
                      end)
    |> Enum.take(count)
    
    Hotsoup.Router.route(rid, jnode)
    
    Stream.repeatedly(fn ->
                        receive do
                          {^jnode, [{}]} -> :ok
                        end
                      end)
    |> Enum.take(count)
  end
end

defmodule Hotsoup.ManyRouterTest do
  use ExUnit.Case

  setup do
    {:ok, rid1} = Hotsoup.Router.start_link
    {:ok, rid2} = Hotsoup.Router.start_link
    {:ok, [rid1: rid1, rid2: rid2]}
  end

  test "Routers are independant",  %{rid1: rid1, rid2: rid2} do
    jnode = :jsx.decode("42")
    Hotsoup.Router.subscribe(rid1, "42", self)
    Hotsoup.Router.route(rid2, jnode)
    refute_receive {^jnode, [{}]}
  end
end
