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

      import unquote(__MODULE__)#, only: [match: 3, match: 4]

      @matchers []
      @before_compile unquote(__MODULE__)
    end
  end
  
  defmacro __before_compile__(_env) do
    quote unquote: false do
      @matchers_by_exp @matchers |> Enum.group_by(fn({k, _expr, _state, _conds, _code}) ->
                                                      k
                                                  end)
                                 |> Enum.map(fn({k, v = [{_k, expr, state, _cond_0, _code_0}|_]}) ->
                                                 {{expr, state}, Enum.map(v, fn({_k, _expr_n, _state_n, cond_n, code_n}) ->
                                                                                 {cond_n, code_n}
                                                                             end)}
                                             end)

      @matchers_by_exp
      |> Enum.each fn({{expr, state}, conds_code}) ->
                       bindings = expr |> extract_capture_names |> build_bindings
                       body = build_body(conds_code)
                       svar = Macro.var(:svar, nil)
                       def do_match(unquote(expr), svar = unquote(state), var!(jnode)) do
                         unquote_splicing(bindings)
                         unquote(body)
                       end
                   end

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
    quote bind_quoted: [key: expr <> Macro.to_string(state),
                        expr: Macro.escape(expr),
                        state: Macro.escape(state),
                        conds: Macro.escape(conds),
                        code: Macro.escape(code)] do
      @matchers [{key, expr, state, conds, code} | @matchers]
    end
  end

  def extract_capture_names(expr) do
    Regex.compile("\\(\\?<([A-Za-z0-9_]+)>[^\\)]*\\)")
    |> elem(1)
    |> Regex.scan(expr, [capture: :all_but_first])
    |> List.flatten
  end

  def build_bindings(vars) do
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

  def build_body([]) do
    quote bind_quoted: [state: Macro.var(:state, nil),
                        jnode: Macro.var(:jnode, nil)] do
      nomatch(state, jnode)
    end
  end
  def build_body([{conds, code} | tail]) do
    ifcond = build_if_conds(conds)
    elsebody = build_body(tail)
    quote do
      if unquote(ifcond) do
        unquote(code)
      else
        unquote(elsebody)
      end
    end
  end

  def build_if_conds(conds) do
    conds
    |> Enum.reduce(true,
                   fn({:when, c}, acc) ->
                       quote do
                         unquote(c) and unquote(acc)
                       end
                   end)
  end
end
