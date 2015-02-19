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

      import unquote(__MODULE__), only: [match: 2]

      @matchers []
      @before_compile unquote(__MODULE__)
    end
  end
  
  defmacro __before_compile__(_env) do
    quote unquote: false do
      @matchers_by_exp @matchers |> Enum.group_by(fn({k, _}) ->
                                                      k
                                                  end)
                                 |> Enum.map(fn {k, v} ->
                                                  fv = v |> Enum.map(fn {k, e} -> e end)
                                                  {k, fv}
                                             end)

     @matchers_by_exp
     |> Enum.each fn({expr, matchers}) ->
                      def do_match({:node, unquote(expr), node}, state) do
                        state = unquote(matchers)
                                |> Enum.reduce(state, fn({m, f}, state) ->
                                                          Kernel.apply(m, f, [node, state])
                                                      end)
                        {:noreply, state}
                      end
                  end

     def do_match(msg, state) do
       nomatch(msg, state)
     end
    end
  end

  defmacro match(expr, [do: code]) do
    << _, _, t :: binary>> = "#{:random.uniform}"
    fname = :"#{__CALLER__.module}.#{expr}.#{t}"
    quote do
      def unquote(fname)(var!(jnode), var!(state)) do
        unquote(code)
      end
      @matchers [{unquote(expr), {unquote(__CALLER__.module), unquote(fname)}} | @matchers]
    end
  end
end
