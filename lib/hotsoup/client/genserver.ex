defmodule Hotsoup.Client.GenServer do
  defmodule Listener do
    def start(expr, pid) do
      Kernel.spawn(__MODULE__, :boot, [expr, pid])
    end

    def start(rid, expr, pid) do
      Kernel.spawn(__MODULE__, :boot, [rid, expr, pid])
    end

    def boot(expr, master) do
      Process.link master
      Hotsoup.Cluster.subscribe(self, expr)
      loop(expr, master)
    end

    def boot(rid, expr, master) do
      Process.link master
      Hotsoup.Router.subscribe(rid, self, expr)
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
  
  defmacro __using__(_opts) do
    quote location: :keep do
      use GenServer
      use Hotsoup.Client.Facade
      require Logger

      def start_link(args) do
        r = {:ok, pid} = GenServer.start_link(__MODULE__, args)
        Enum.each(expressions, &Listener.start(&1, pid))
        r
      end

      def start_link(rid, args) do
        r = {:ok, pid} = GenServer.start_link(__MODULE__, args)
        Enum.each(expressions, &Listener.start(rid, &1, pid))
        r
      end

      def nomatch(jnode, state) do
        {:stop, {:nomatch, jnode}, state}
      end

      def handle_cast({:node, pattern, jnode}, state) do
        do_match(pattern, jnode, state)
      end

      defoverridable [start_link: 1, start_link: 2,  nomatch: 2]

      import unquote(__MODULE__)
    end
  end
end
