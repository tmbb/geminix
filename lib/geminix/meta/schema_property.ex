defmodule Geminix.Meta.SchemaProperty do
  @moduledoc false
  alias Geminix.Meta.Types

  defstruct api_name: nil,
            elixir_name: nil,
            description: nil,
            required: nil,
            type: nil,
            ecto_field: nil,
            ecto_type: nil,
            markdown_type: nil,
            quoted_type: nil

  def from_property_map(property_map) do
    for {name, map} <- property_map do
      from_map(name, map)
    end
  end

  def from_map(name, map) do
    elixir_name = Macro.underscore(name)
    raw_description = map["description"]

    {required, description} =
      cond do
        raw_description == nil ->
          {false, "**No description**"}

        String.starts_with?(raw_description, "Required. ") ->
          "Required. " <> rest = raw_description
          description = "**Required**. " <> rest
          {true, description}

        String.starts_with?(raw_description, "Optional. ") ->
          "Optional. " <> rest = raw_description
          description = "*Optional*. " <> rest
          {false, description}

        true ->
          {false, raw_description}
      end

    type = Types.type_of(elixir_name, map)

    %__MODULE__{
      api_name: name,
      elixir_name: elixir_name,
      description: description,
      required: required,
      type: type,
      ecto_field: Types.type_to_ecto(elixir_name, type),
      markdown_type: Types.type_to_markdown(type),
      quoted_type: Types.type_to_quoted(type)
    }
  end
end
