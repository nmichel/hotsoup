defmodule Hotsoup do
  use Application
  use Hotsoup.Logger

  def start(_type, _args) do
    Hotsoup.Logger.info(["Hotsoup is on the table !"])
    
    Hotsoup.Supervisor.start_link
  end
end
