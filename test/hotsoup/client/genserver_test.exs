defmodule Hotsoup.Client.GenServerTest.MyClient do
  use Hotsoup.Client.GenServer

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
end

defmodule Hotsoup.Client.GenServerTest do
  use ExUnit.Case

  setup do
    alias Hotsoup.Client.GenServerTest.MyClient
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
    GenServer.cast(pid, {:node, "[*, (?<val>_)]", {:ok, [v2: ["toto"], val: [42, 13]]}}) # will match
    assert_receive {:match, :rule3}
    assert Process.info(pid)[:messages] == [] # all messages processed
  end

  test "exception raised when missing name in captures set", context do
    GenServer.cast(context[:pid], {:node, "[*, (?<val>_)]", {:ok, [v2: ["foo"]]}}) # missing val
    assert_receive {:EXIT, _, {{:badmatch, _}, _}}
  end
end

defmodule Hotsoup.Client.GenServerTest.MyWhenClient do
  use Hotsoup.Client.GenServer

  def init(args) do
    {:ok, %{master: args[:master],
            nodes: []}}
  end

  defp check_some_properties(l) do
    l == ["foo"]
  end

  match "[*, (?<v1>_), {_: (?<v2>_)}]", %{master: master} = state,
    when: check_some_properties(v2),
    when: List.first(Enum.reverse(v1)) == 42
  do
    send(master, {:match, :rule4})
    {:noreply, state}
  end

  match "[*, (?<v1>_), {_: (?<v2>_)}]", %{master: master} = state,
    when: check_some_properties(v2)
  do
    send(master, {:match, :rule5})
    {:noreply, state}
  end
end


defmodule Hotsoup.Client.GenServerWhenTest do
  use ExUnit.Case

  setup do
    alias Hotsoup.Client.GenServerTest.MyWhenClient
    Process.flag(:trap_exit, true)
    {:ok, pid} = MyWhenClient.start_link([master: self])
    {:ok, [pid: pid]}
  end

  test "many :when cond evaluated", context do
    pid = context[:pid]
    GenServer.cast(pid, {:node, "[*, (?<v1>_), {_: (?<v2>_)}]",
                         {:ok, [v2: ["foo"], v1: [1, 2, "foo", 42]]}}) # will match
    assert_receive {:match, :rule4}
    assert Process.info(pid)[:messages] == [] # all messages processed
  end

  test "another :when conditions set match", context do
    pid = context[:pid]
    GenServer.cast(pid, {:node, "[*, (?<v1>_), {_: (?<v2>_)}]",
                         {:ok, [v2: ["foo"], v1: [1, 2]]}}) # will match
    assert_receive {:match, :rule5}
    assert Process.info(pid)[:messages] == [] # all messages processed
  end

  test "exception raised when no when: conditions set is fully met", context do
    pid = context[:pid]

    GenServer.cast(pid, {:node, "[*, (?<v1>_), {_: (?<v2>_)}]",
                         {:ok, [v2: ["neh"], v1: [13, 42]]}}) # won't match
    assert_receive {:EXIT, _, _}
  end
end

defmodule Hotsoup.Client.GenServerTest.MyCatchallClient do
  use Hotsoup.Client.GenServer

  def init(args) do
    {:ok, %{master: args[:master]}}
  end

  def nomatch(_node, %{master: master} = state) do
    send(master, {:match, :default})
    {:noreply, state}
  end
end

defmodule Hotsoup.Client.GenServerCatchallTest do
  use ExUnit.Case

  setup do
    alias Hotsoup.Client.GenServerTest.MyCatchallClient

    Process.flag(:trap_exit, true)
    {:ok, pid} = MyCatchallClient.start_link([master: self])
    {:ok, [pid: pid]}
  end

  test "catch non matching node in nomatch/2", context do
    pid = context[:pid]

    GenServer.cast(pid, {:node, "[*, (?<v1>_), {_: (?<v2>_)}]", {:ok, [v2: ["foo"], v1: [1, 2, "foo", 42]]}})
    assert_receive {:match, :default}
  end
end
