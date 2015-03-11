defmodule Hotsoup do
  use Application
  use Hotsoup.Logger
  alias Hotsoup.Cluster
  alias Hotsoup.Supervisor

  # API
  
  @doc """
    Drop JSON node `jnode` in the soup.
    
    Example:
  
      iex> jnode = :jsx.decode("{\\"foo\\": 42}")
      iex> Hotsoup.route(jnode)
  """
  def route(jnode) do
    Cluster.route(jnode)
  end
  
  @doc """
    Subscribe caller process to `pattern`
  """
  def subscribe(pattern) do
    Cluster.subscribe(self(), pattern)
  end
  
  @doc """
    Unsubscribe caller process from all patterns
  """
  def unsubscribe() do
    Cluster.unsubscribe(self())
  end
  
  # Callbacks Application
  
  def start(_type, _args) do
    info(["Hotsoup is on the table !"])
    
    Supervisor.start_link
  end
end
