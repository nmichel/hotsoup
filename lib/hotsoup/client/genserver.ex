defmodule Hotsoup.Client.GenServer do
  defmodule Listener do
    def start_link(expr) do
      Kernel.spawn_link(__MODULE__, :boot, [expr, self])
    end

    def boot(expr, master) do
      Hotsoup.Cluster.subscribe(self, expr)
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

      def start_link(args \\ nil) do
        GenServer.start_link(__MODULE__, args)
      end

      def init(state) do
        Enum.each(expressions, &Listener.start_link(&1))
        {:ok, state}
      end

      def nomatch(jnode, state) do
        {:stop, {:nomatch, jnode}, state}
      end

      def handle_cast({:node, pattern, jnode}, state) do
        do_match(pattern, jnode, state)
      end

      defoverridable [start_link: 1, init: 1, nomatch: 2]

      import unquote(__MODULE__)
    end
  end
end
