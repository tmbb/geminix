defmodule Geminix do
  @moduledoc """
  Documentation for `Geminix`.
  """

  alias Geminix.Meta

  require Logger
  # require Geminix.Meta, as: Meta

  api_data = File.read!("vendor/v1beta_api.json") |> Jason.decode!()

  # TODO: these modules define functions that raise when they are called
  # We need to flesh out the implementation
  Meta.create_resource_modules(api_data)

  # Create the API modules
  Meta.create_schema_modules(api_data)
end
