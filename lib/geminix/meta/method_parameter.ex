defmodule Geminix.Meta.MethodParameter do
  @moduledoc false
  alias Geminix.Meta.Types

  defstruct api_name: nil,
            elixir_name: nil,
            description: nil,
            location: nil,
            type: nil,
            type_markdown: nil,
            type_quoted: nil

  def validate_location!(location) do
    case location do
      "query" -> :query
      "path" -> :path
    end
  end

  def from_map(name, map) do
    api_name = name
    elixir_name = Macro.underscore(api_name)
    type = Types.type_of(elixir_name, map)
    type_markdown = Types.type_to_markdown(type)
    type_quoted = Types.type_to_quoted(type)

    %__MODULE__{
      api_name: api_name,
      elixir_name: elixir_name,
      description: map["description"],
      location: validate_location!(map["location"]),
      type: type,
      type_markdown: type_markdown,
      type_quoted: type_quoted
    }
  end
end
