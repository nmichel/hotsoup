defmodule Hotsoup.Router.ClientTest do
  use ExUnit.Case
  require Helper
	
  defmodule MySimplestClient do
    use Hotsoup.Router.Client
    use Hotsoup.Logger
    
    match "42", state = %{nodes: nodes} do
      Hotsoup.Logger.info ["Received 42: ", jnode, ", history: ", nodes]
      %{state | nodes: [jnode | nodes]}
    end
    
    match "42", state = %{name: name} do
      Hotsoup.Logger.info ["Received 42: ", jnode, ", name: ", name]
      state
    end

		match "42", state do
      Hotsoup.Logger.info ["Received 42: ", jnode, ", default"]
			state
		end
  end
end


# defmodule Hotsoup.Router.ClientTest do
#   use ExUnit.Case
#   require Helper
  
#   defmodule MySimplestClient do
#     use Hotsoup.Router.Client
#     use Hotsoup.Logger
    
#     match "42" do
#       Hotsoup.Logger.info ["Received 42: ", jnode, ", history: ", state]
#       [jnode | state]
#     end
#   end

#   test "Route one node then kill with non routable node", _context do
#     use Hotsoup.Logger
#     Process.flag(:trap_exit, true)

#     {:ok, pid} = MySimplestClient.start_link([])
#     GenServer.cast(pid, {:node, "42", :ok})
#     GenServer.cast(pid, {:node, "DIE", :ok})
#     Helper.wait(1000)

#     assert(receive do
#              {:EXIT, ^pid, {:nomatch, {:node, "DIE", :ok}}} -> true
#              _ -> false
#            after
#              1000 -> false
#            end)
#   end

#   defmodule MyClient do
#     use Hotsoup.Router.Client
#     use Hotsoup.Logger

#     def init(_args) do
#       Hotsoup.Logger.info(["INIT :) :)"])
#       {:ok, %{nodes: []}}
#     end

#     def nomatch(node, state) do
#       Hotsoup.Logger.info([" No match for node", node, " with state ", state])
#       # super(node, state)
#       {:noreply, state}
#     end

#     match "42" do
#       %{nodes: nodes} = state
#       Hotsoup.Logger.info ["Received 42: ", jnode, ", history: ", nodes]
#       %{state | nodes: [jnode | nodes]}
#     end
    
#     match "[*]" do
#       %{nodes: nodes} = state
#       Hotsoup.Logger.info ["Received [*]: ", jnode, ", history: ", nodes]
#       %{state | nodes: [jnode | nodes]}
#     end
    
#     match "42" do
#       %{nodes: nodes} = state
#       Hotsoup.Logger.info ["Received 42 twice: ", jnode, ", history: ", nodes]
#       %{state | nodes: [jnode | nodes]}
#     end
#   end
    
#   test "Route node to client", _context do
#     Process.flag(:trap_exit, true)
#     {:ok, pid} = MyClient.start_link
#     GenServer.cast(pid, {:node, "42", :ok})
#     GenServer.cast(pid, {:node, "DIE", :ok})
#   end
# end
