defmodule Hotsoup do
  use Application
  use Hotsoup.Logger
  alias Hotsoup.Cluster
  alias Hotsoup.Router
  alias Hotsoup.Supervisor

  @moduledoc """
    Provide a high level, easy to use, set of functions to play with the soup.

    Example:
    
      iex> Hotsoup.subscribe "{_:42}"
      iex> jnode = Hotsoup.Helpers.decode("{\\"foo\\": 42}")
      iex> Hotsoup.route(jnode)
      iex> receive do
      ...> m -> m
      ...> end
      {[{"foo", 42}], [{}]}
  """
  
  # API

  @doc """
    Get the JSON backend module.
    
    Currently supported :
    - jsx
  """
  def get_json_backend do
    Application.get_env(:hotsoup, :backend)
  end

  @doc """
    Decode `text` using the JSON backend specified by configuration.
  """
  def decode(text) when is_binary(text) do
    try do
      jnode = :ejpet.decode(text, get_json_backend) 
      {:ok, jnode}
    rescue
      _ -> :error
    end
  end

  @doc """
    Encode `jnode` using the JSON backend specified by configuration.
  """
  def encode(jnode) do
    try do
      text = :ejpet.encode(jnode, get_json_backend)
      {:ok, text}
    rescue
      _ -> :error
    end
  end

  @doc """
  """
  def get_router(opts \\ Router.default_options) do
    Cluster.get_router(opts)
  end
  
  @doc """
    Drop JSON node `jnode` in the soup, using default `Router`.
  """
  def route(jnode) do
    Cluster.route(jnode)
  end

  @doc """
    Drop JSON node `jnode` in the soup, using specified `Router`.
  """
  def route(jnode, rid) do
    Router.route(rid, jnode)
  end
  
  @doc """
    Subscribe caller process to `pattern`
  """
  def subscribe(pattern) do
    Cluster.subscribe(self, pattern)
  end
  
  @doc """
    Subscribe process `pid` to `pattern`
  """
  def subscribe(pid, pattern) when is_pid(pid) do
    Cluster.subscribe(pid, pattern)
  end
  
  @doc """
    Unsubscribe caller process from all patterns
  """
  def unsubscribe() do
    Cluster.unsubscribe(self)
  end
  
  @doc """
    Unsubscribe process `pid` from all patterns
  """
  def unsubscribe(pid) when is_pid(pid) do
    Cluster.unsubscribe(pid)
  end
  
  # Callbacks Application
  
  def start(_type, _args) do
    info(["Hotsoup is on the table !"])
    
    Supervisor.start_link
  end
end
