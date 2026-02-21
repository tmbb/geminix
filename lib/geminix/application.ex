defmodule Geminix.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Geminix.Cache, []}
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
