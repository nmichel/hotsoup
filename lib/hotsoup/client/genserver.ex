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
  
  defmacro __using__(opts) do
    defaults = build_defaults

    quote location: :keep do
      use GenServer
      use Hotsoup.Client.Facade, unquote(opts)
      import unquote(__MODULE__)

      @nomatch unquote(opts)[:nomatch] || :nomatch
      @domatch unquote(opts)[:do_match] || :do_match

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
       
      unquote(defaults)

      defoverridable [start_link: 1, start_link: 2]
    end
  end

  defp build_defaults do
    quote location: :keep, unquote: false do
      def handle_cast(n = {:node, pattern, jnode}, state) do
        unquote(@domatch)(pattern, jnode, state)
      end

      def unquote(@nomatch)(jnode, state) do
        {:stop, {:nomatch, jnode}, state}
      end

      defoverridable [{@nomatch, 2}]
    end
  end
end
