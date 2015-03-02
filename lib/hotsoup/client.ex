defmodule Hotsoup.Router.Client do
  defmacro __using__(_opts) do
    quote location: :keep do
      use GenServer
      use Hotsoup.Router.Facade
      use Hotsoup.Logger

      def start_link(args \\ []) do
        GenServer.start_link(__MODULE__, args)
      end

      def init(args) do
        {:ok, args}
      end

      def handle_cast({:node, pattern, jnode}, state) do
        do_match(pattern, state, jnode)
      end
      
      defoverridable [init: 1]

      import unquote(__MODULE__)
    end
  end
end
