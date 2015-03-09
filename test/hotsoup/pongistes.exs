defmodule Protocol do
  defmacro __using__(_opts) do
    import Hotsoup.Client.DSL
    
    quote do
      @ping   object with: [key: "action", value: "ping"]
      @pong   object with: [key: "action", value: "pong"]
      @start  object with: [key: "action", value: "start"]
      @stop   object with: [key: "action", value: "stop"]
      @action object with: [key: "action", value: capture(:any, as: "action")]
    end
  end
end

defmodule Ping do
  use Hotsoup.Client.GenServer
  use Protocol
  
  def init(nil) do
    {:ok, rid} = Hotsoup.Cluster.get_router(ttl: 1000)
    super {0, rid}
  end

  match @ping, {counter, rid} do
  # match "{\"action\": \"ping\"}", {counter, rid} do
    Hotsoup.Router.route(rid, :jsx.decode("{'action': 'pong'}"))
    {:noreply, {counter+1, rid}}
  end

  match @stop, state do
    {:stop, state}
  end
end

defmodule Pong do
  use Hotsoup.Client.GenServer
  use Protocol

  def start_link(n) when is_integer(n) do
    super n
  end
  
  def init(n) do
    {:ok, rid} = Hotsoup.Cluster.get_router(ttl: 1000)
    super {0, {n, rid}}
  end

  match @pong, state = {n, {n, rid}} do
    Hotsoup.Router.route(rid, :jsx.decode("{'action': 'stop'}"))
    {:noreply, state}
  end
  match @pong, {counter, inner = {_, rid}} do
    Hotsoup.Router.route(rid, :jsx.decode("{'action': 'ping'}"))
    {:noreply, {counter+1, inner}}
  end

  match @stop, state do
    {:stop, state}
  end
end

defmodule Starter do
  use Hotsoup.Client.GenServer
  use Protocol
  
  def init(nil) do
    {:ok, rid} = Hotsoup.Cluster.get_router(ttl: 1000)
    super rid
  end

  match @start, rid do
    Hotsoup.Router.route(rid, :jsx.decode("{'action': 'ping'}"))
    {:stop, rid}
  end
end

defmodule Monitor do
  use Hotsoup.Client.GenServer
  use Protocol

  def init(nil) do
    super %{ping: 0, pong: 0, other: 0, total: 0}
  end

  match @action, state,
    when: action == ["ping"]
  do
    {:noreply, %{state | ping: state[:ping]+1, total: state[:total]+1}}
  end

  match @action, state,
    when: action == ["pong"]
  do
    {:noreply, %{state | pong: state[:pong]+1, total: state[:total]+1}}
  end
  # clause
  #   match "{\"action\": (?<action>_)}", state = %{other: other} do ...
  # won't work as expected, because clauses
  #   match "{\"action\": (?<action>_)}", state, ...
  # will catch all nodes routed through  "{\"action\": (?<action>_)}"
  # Use a default clause and destructure inside it, as follows.
  #
  # Warning ! The following clause will get all nodes except "ping" and "pong", even "stop" might be caught.
  # 
  # match "{\"action\": (?<action>_)}", state do
  #   IO.puts ["action: action ! ", inspect(jnode)]
  #   %{other: other, total: total} = state
  #   {:noreply, %{state | other: other+1, total: total+1}}
  # end
  match @action, state,
    when: action != ["stop"]
  do
    %{other: other, total: total} = state
    {:noreply, %{state | other: other+1, total: total+1}}
  end
  match @action, state do
    # noop clause
    {:noreply, state}
  end

  # Warning ! The following clause is a "catchall". Each node will match the expression
  # Therefore, "start", "ping", "pong" message will get caught by this clause (and the
  # others too);  even "stop" depending on if this clause is called  before the one
  # dedicated to "stop" (see bellow).
  # 
  match "{\"action\": (?<action_too>_)}", state do
    {:noreply, state}
  end

  match @stop, state do
    {:stop, %{state | other: state[:other]+1, total: state[:total]+1}}
  end
end

Process.flag(:trap_exit, true)

Pong.start_link 10
Ping.start_link
Starter.start_link
{:ok, monitor} = Monitor.start_link

{:ok, rid} = Hotsoup.Cluster.get_router(ttl: 1000)
Hotsoup.Router.route(rid, :jsx.decode("{'action': 'start'}"))

receive do
  {:EXIT, ^monitor, s} ->
    IO.puts ["******** => ", inspect(s)]
end

