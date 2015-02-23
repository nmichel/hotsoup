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

      def nomatch(state, jnode) do
        {:stop, {:nomatch, jnode}, state}
      end

      def handle_cast({:node, pattern, jnode}, state) do
        do_match(pattern, state, jnode)
      end
      
      defoverridable [init: 1, nomatch: 2]

      import unquote(__MODULE__), only: [match: 3, match: 4]

      @before_compile unquote(__MODULE__)
    end
  end
  
  defmacro __before_compile__(_env) do
    quote do
      def do_match(pattern, state, jnode) do
        nomatch(state, jnode)
      end
    end
  end

  defmacro match(expr, state, code) do
    quote location: :keep do
      match(unquote(expr), unquote(state), [], unquote(code))
    end
  end

  defmacro match(expr, state, conds, [do: code]) do
    generate(expr, state, conds, code)
  end

  defp generate(expr, state, conds, code) do
    bindings = expr |> extract_capture_names |> build_bindings
    ifcond = conds |> build_if_conds
    
    quote do
      svar = Macro.var(:svar, nil)
      def do_match(unquote(expr), svar = unquote(state), var!(jnode)) do
        unquote_splicing(bindings)
        if unquote(ifcond) do
          unquote(code)
        else
          {:noreply, svar}
        end
      end
    end
  end

  defp extract_capture_names(expr) do
    Regex.compile("\\(\\?<([A-Za-z0-9_]+)>[^\\)]*\\)")
    |> elem(1)
    |> Regex.scan(expr, [capture: :all_but_first])
    |> List.flatten
  end

  defp build_bindings(vars) do
    vars
    |> Enum.map(fn(name) ->
                    va = String.to_atom(name)
                    v = Macro.var(va, nil)
                    quote do
                      {:ok, l} = Keyword.fetch(elem(var!(jnode), 1), unquote(va))
                      unquote(v) = l
                    end
                end)
  end

  defp build_if_conds(conds) do
    conds
    |> Enum.reduce(true,
                   fn({:when, c}, acc) ->
                       quote do
                         unquote(c) and unquote(acc)
                       end
                   end)
  end
end
