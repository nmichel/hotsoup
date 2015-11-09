use Mix.Config
        
config :hotsoup,
  backend: :jsx
         
config :logger,
  :console, level: :warn

import_config "#{Mix.env}.exs"
