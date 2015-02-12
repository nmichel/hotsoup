defmodule HotsoupRoute do
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
    {:ok, rid} = Hotsoup.RouterManager.start_router
    {:ok, cid} = Client.start(self())
    {:ok, [rid: rid, cid: cid]}
  end

  test "Can register listener", %{rid: rid, cid: cid} do
    Hotsoup.Router.register rid, "42", cid
    n = :jsx.decode "42"
    Hotsoup.Router.route rid, n
    assert Client.expect {n, [{}]}
  end

  test "Can unregister listener", %{rid: rid, cid: cid} do
    n = :jsx.decode "42"
    Hotsoup.Router.register rid, "42", cid
    Hotsoup.Router.route rid, n
    assert Client.expect {n, [{}]}
    Hotsoup.Router.unregister rid, cid
    Hotsoup.Router.route rid, n
    assert Client.do_not_expect {n, [{}]}
  end
end
