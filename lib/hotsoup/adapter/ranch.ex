defmodule Hotsoup.Adapter.PrococolHandler do
  defmodule Listener do
    def start_link(rid, expr) do
      Kernel.spawn_link(__MODULE__, :boot, [rid, expr, self])
    end

    def boot(rid, expr, master) do
      Hotsoup.Router.subscribe(rid, expr, self)
      loop(expr, master)
    end

    def loop(expr, master) do
      receive do
        jnode ->
          GenServer.cast(master, {:node, expr, jnode})
          loop(expr, master)
      end
    end
  end
  
  use GenServer
  use Hotsoup.Client.Facade
  use Hotsoup.Client.Expr
  import Hotsoup

  def start_link(rid, writer_id) do
    GenServer.start_link(__MODULE__, [rid, writer_id])
  end

  def init([rid, writer_id]) do
    Enum.each(expressions, &Listener.start_link(rid, &1))
    {:ok, [rid, writer_id]}
  end

  def nomatch(jnode, state) do
    {:stop, {:nomatch, jnode}, state}
  end

  def handle_cast({:node, pattern, jnode}, state) do
    do_match(pattern, jnode, state)
  end

  @subscribe object(with: [key: "subscribe",
                           value: capture(:any, as: "pattern")])
  match @subscribe, state = [_rid, writer_id] do
    [p | _] = pattern
    Hotsoup.subscribe(writer_id, p)
    {:noreply, state}
  end

  @unsubscribe object(with: [key: "unsubscribe",
                             value: capture(:any, as: "pattern")])
  match @unsubscribe, state = [_rid, writer_id] do
    Hotsoup.unsubscribe(writer_id)
    {:noreply, state}
  end
end

defmodule Hotsoup.Ranch.Protocol.Writer do
  def start_link(socket, transport, opts) do
    pid = Kernel.spawn_link(__MODULE__, :init, [socket, transport, opts])
    {:ok, pid}
  end

  def init(socket, transport, opts) do
    loop(socket, transport)
  end

  def loop(socket, transport) do
  	receive do
  		{jnode, _captures} ->
  		  {:ok, text} = Hotsoup.encode(jnode)
  			transport.send(socket, text)
  			loop(socket, transport)
  	end
  end
end

defmodule Hotsoup.Ranch.Protocol do
  @behaviour :ranch_protocol
  
  def start_link(ref, socket, transport, opts) do
    {:ok, writer_id} = Hotsoup.Ranch.Protocol.Writer.start_link(socket, transport, [])
    reader_id = Kernel.spawn_link(__MODULE__, :init, [ref, socket, transport, [writer_id: writer_id]])
    {:ok, reader_id}
  end

  def init(ref, socket, transport, [writer_id: writer_id]) do
    {:ok, rid} = Hotsoup.Router.start_link
    {:ok, _} = Hotsoup.Adapter.PrococolHandler.start_link(rid, writer_id)
    :ok = :ranch.accept_ack(ref)
    loop(socket, transport, rid)
  end

  def loop(socket, transport, rid) do
  	case transport.recv(socket, 0, 50000) do
  		{:ok, data} ->
    		case Hotsoup.decode(data) do
  		    {:ok, jnode} ->
      			Hotsoup.Router.route(rid, jnode)
  			    Hotsoup.route(jnode)
  			    loop(socket, transport, rid)
  		    :error ->
  			    loop(socket, transport, rid)
  			   _ ->
      			transport.close(socket)
      	end
  		{:error, :timeout} ->
  			loop(socket, transport, rid)
      _ ->
  			:ok = transport.close(socket)
  	end
  end
end

defmodule Hotsoup.Ranch.Adapter do
  def start do
    {:ok, _} = Application.ensure_all_started(:ranch)
    {:ok, _} = :ranch.start_listener(:ranch_adapter, 100, :ranch_tcp, [port: 5555], Hotsoup.Ranch.Protocol, [])
  end
end

"""
Application.start :ranch
:ranch.start_listener(:tcp_echo, 100, :ranch_tcp, [port: 5555], Hotsoup.Ranch.Protocol, [])
"""
