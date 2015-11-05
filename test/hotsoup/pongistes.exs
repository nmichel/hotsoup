defmodule Pongistes do
  defmodule Protocol do
    defmacro __using__(_opts) do
      quote do
        import Hotsoup
        import Hotsoup.Client.Expr
      
        @ping   object with: [key: "action", value: "ping"]
        @pong   object with: [key: "action", value: "pong"]
        @start  object with: [key: "action", value: "start"]
        @stop   object with: [key: "action", value: "stop"]
        
        @varname "action"
        @action object with: [key: "action", value: capture(:any, as: @varname)]
      end
    end
  end
  
  defmodule Ping do
    use Hotsoup.Client.GenServer
    use Protocol
    
    def init(nil) do
      {:ok, rid} = get_router(ttl: 1000)
      {:ok, {1, rid}}
    end
  
    match @ping, {counter, rid} do
      {:ok, n} = decode("{'action': 'pong'}")
      route(n, rid)
      {:noreply, {counter+1, rid}}
    end
  
    match @stop, state do
      {:stop, :stop, state}
    end
  end
  
  defmodule Pong do
    use Hotsoup.Client.GenServer
    use Protocol
  
    def start_link(n) when is_integer(n) do
      super n
    end
    
    def init(n) do
      {:ok, rid} = get_router(ttl: 1000)
      {:ok, {1, {n, rid}}}
    end
  
    @pattern @pong
    match state = {n, {n, rid}} do
      {:ok, n} = decode("{'action': 'stop'}")
      route(n, rid)
      {:noreply, state}
    end
    match {counter, inner = {_, rid}} do
      {:ok, n} = decode("{'action': 'ping'}")
      route(n, rid)
      {:noreply, {counter+1, inner}}
    end
  
    match @stop, state do
      {:stop, :stop, state}
    end
  end
  
  defmodule Starter do
    use Hotsoup.Client.GenServer
    use Protocol
    
    def init(nil) do
      {:ok, rid} = get_router(ttl: 1000)
    end
  
    match @start, rid do
      {:ok, n} = decode("{'action': 'ping'}")
      route(n, rid)
      {:stop, :stop, rid}
    end
  end

  defmodule Monitor do
    use Hotsoup.Client.GenServer
    use Protocol
  
    def init(master) do
      {:ok, %{master: master, ping: 0, pong: 0, other: 0, total: 0}}
    end
  
    @pattern @action
    match state, when: action == ["ping"]
    do
      {:noreply, %{state | ping: state[:ping]+1, total: state[:total]+1}}
    end
    match state, when: action == ["pong"]
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
    match state, when: action != ["stop"]
    do
      %{other: other, total: total} = state
      {:noreply, %{state | other: other+1, total: total+1}}
    end
    match state do
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
  
    match @stop, state = %{master: m} do
      r = %{state | other: state[:other]+1, total: state[:total]+1}
      send(m, r)
      {:stop, :stop, r}
    end
  end
end

defmodule Pongistes.Test do
  use ExUnit.Case
  import Hotsoup

  test "pongistes play" do
    Process.flag(:trap_exit, true)
    
    count = 10
    ping = count
    pong = count
    other = 5 # start x 4 + stop
    total = ping + pong + other
    
    {:ok, _} = Pongistes.Pong.start_link(count)
    {:ok, _} = Pongistes.Ping.start_link nil
    {:ok, _} = Pongistes.Starter.start_link nil
    {:ok, m} = Pongistes.Monitor.start_link self
    
    {:ok, n} = decode("{'action': 'start'}")
    route n
    
    assert_receive %{master: self, other: 5, ping: ^ping, pong: ^pong, total: ^total}, 1000
  end
end
