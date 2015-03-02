defmodule Hotsoup.Router.Client do
  defmacro __using__(_opts) do
    quote location: :keep do
      use GenServer
      use Hotsoup.Router.Facade
      use Hotsoup.Logger

      def start_link(args) do
        GenServer.start_link(__MODULE__, args)
      end

      def init(state) do
        {:ok, state}
      end

      def nomatch(jnode, state) do
        {:stop, {:nomatch, jnode}, state}
      end

      def handle_cast({:node, pattern, jnode}, state) do
        do_match(pattern, jnode, state)
      end
      
      defoverridable [init: 1, nomatch: 2]

      import unquote(__MODULE__)
    end
  end
end
