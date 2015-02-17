defmodule Hotsoup.RouterTest do
  use ExUnit.Case
  doctest Hotsoup

  defmodule Client do
    def loop(tgt) do
      receive do
        :stop ->
          :ok
        n ->
          send tgt, n
          loop tgt
      end
    end

    def start(tgt) do
      Task.start(fn() -> loop(tgt) end)
    end
    
    def expect(m) do
      receive do
        ^m -> true
        _ -> false
      end
    end
    
    def do_not_expect(m) do
      receive do
        ^m -> false
      after
        1000 -> true
      end
    end
  end

  setup do
    {:ok, rid} = Hotsoup.Router.start_link
    {:ok, cid} = Client.start(self())
    {:ok, [rid: rid, cid: cid]}
  end

  test "Can subscribe listener", %{rid: rid, cid: cid} do
    n = :jsx.decode("42")
    Hotsoup.Router.subscribe(rid, "42", cid)
    Hotsoup.Router.route(rid, n)
    assert Client.expect({n, [{}]})
  end

  test "Can unsubscribe listener", %{rid: rid, cid: cid} do
    n = :jsx.decode("42")
    Hotsoup.Router.subscribe(rid, "42", cid)
    Hotsoup.Router.route(rid, n)
    assert Client.expect({n, [{}]})
    Hotsoup.Router.unsubscribe(rid, cid)
    Hotsoup.Router.route(rid, n)
    assert Client.do_not_expect({n, [{}]})
  end
end
