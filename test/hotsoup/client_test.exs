defmodule Hotsoup.Router.ClientTest.MyClient do
  use Hotsoup.Router.Client
  use Hotsoup.Logger
  
  def init(args) do
    {:ok, %{master: args[:master],
            nodes: []}}
  end

  match "42", state = %{master: master, nodes: [] = nodes} do
    send(master, {:match, :rule1})
    {:noreply, %{state | nodes: [jnode | nodes]}}
  end

  match "42", state = %{master: master, nodes: [:node42] = nodes} do
    send(master, {:match, :rule2})
    {:noreply, %{state | nodes: [jnode | nodes]}}
  end

  match "[*, (?<val>_)]", %{master: master} = state,
    when: List.first(val) == 42
  do
    send(master, {:match, :rule3})
    {:noreply, state}
  end

  defp check_some_properties(l) do
    l == ["foo"]
  end

  match "[*, (?<v1>_), {_: (?<v2>)}]", %{master: master} = state,
    when: check_some_properties(v2),
    when: List.first(Enum.reverse(v1)) == 42
  do
    send(master, {:match, :rule4})
    {:noreply, state}
  end
end

defmodule Hotsoup.Router.ClientTest do
  use ExUnit.Case
  require Helper

  setup do
    alias Hotsoup.Router.ClientTest.MyClient
    Process.flag(:trap_exit, true)
    {:ok, pid} = MyClient.start_link([master: self])
    {:ok, [pid: pid]}
  end

  test "route depending on state", context do
    GenServer.cast(context[:pid], {:node, "42", :node42})
    assert_receive {:match, :rule1}

    GenServer.cast(context[:pid], {:node, "42", :other})
    assert_receive {:match, :rule2}
  end

  test "by default, die if no route", context do
    GenServer.cast(context[:pid], {:node, "DIE", :no})
    assert_receive {:EXIT, _, _}
  end

  test "one :when cond evaluated", context do
    pid = context[:pid]

    GenServer.cast(pid, {:node, "[*, (?<val>_)]", {:ok, [v2: ["toto"], val: [13, 42]]}}) # won't match
    GenServer.cast(pid, {:node, "[*, (?<val>_)]", {:ok, [v2: ["toto"], val: [42, 13]]}}) # will match
    assert_receive {:match, :rule3}
    assert Process.info(pid)[:messages] == [] # all messages processed
  end

  test "many :when cond evaluated", context do
    pid = context[:pid]

    GenServer.cast(pid, {:node, "[*, (?<v1>_), {_: (?<v2>)}]", {:ok, [v2: ["foo"], v1: [42, "bar"]]}}) # won't match
    GenServer.cast(pid, {:node, "[*, (?<v1>_), {_: (?<v2>)}]", {:ok, [v2: ["neh"], v1: [13, 42]]}}) # won't match
    GenServer.cast(pid, {:node, "[*, (?<v1>_), {_: (?<v2>)}]", {:ok, [v2: ["foo"], v1: [1, 2, "foo", 42]]}}) # will match
    assert_receive {:match, :rule4}
    assert Process.info(pid)[:messages] == [] # all messages processed
  end
end

defmodule Hotsoup.Router.ClientTest.MyCatchallClient do
  use Hotsoup.Router.Client
  use Hotsoup.Logger

  def init(args) do
    {:ok, %{master: args[:master]}}
  end

  def nomatch(%{master: master} = state, _node) do
    send(master, {:match, :default})
    {:noreply, state}
  end
end

defmodule Hotsoup.Router.ClientCatchallTest do
  use ExUnit.Case
  require Helper

  setup do
    alias Hotsoup.Router.ClientTest.MyCatchallClient

    Process.flag(:trap_exit, true)
    {:ok, pid} = MyCatchallClient.start_link([master: self])
    {:ok, [pid: pid]}
  end

  test "catch non matching node in nomatch/2", context do
    pid = context[:pid]

    GenServer.cast(pid, {:node, "[*, (?<v1>_), {_: (?<v2>)}]", {:ok, [v2: ["foo"], v1: [1, 2, "foo", 42]]}})
    assert_receive {:match, :default}
  end
end