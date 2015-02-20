# TODO
# * only one match/2 statement per expression

defmodule Hotsoup.Router.Client do
  defmacro __using__(_opts) do
    quote location: :keep do
      use GenServer
      use Hotsoup.Logger

      def start_link(args \\ []) do
        GenServer.start_link(__MODULE__, args)
      end

      def init(args) do
        {:ok, args}
      end

      def nomatch(node, state) do
        {:stop, {:nomatch, node}, state}
      end

      def handle_cast(msg, state) do
        do_match(msg, state)
      end
      
      defoverridable [init: 1, nomatch: 2]

      import unquote(__MODULE__), only: [match: 3]

      @before_compile unquote(__MODULE__)
    end
  end
  
  defmacro __before_compile__(_env) do
    quote do			
			def do_match(msg, state) do
				nomatch(msg, state)
			end
    end
  end

  defmacro match(expr, state, [do: code]) do
		generate(expr, state, code)
  end

	defp generate(expr, state, code) do
    quote do
      def do_match(var!(jnode), unquote(state)) do
        unquote(code)
      end
    end
	end
end
