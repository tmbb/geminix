import Config

config :geminix,
  api_key: File.read!("secrets/gemini-api-key.txt")
