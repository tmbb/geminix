defmodule Geminix.Meta.Method do
  @moduledoc false

  alias Geminix.Meta.Types
  alias Geminix.Meta.MethodParameters

  defstruct id: nil,
            api_name: nil,
            elixir_name: nil,
            path: nil,
            flat_path: nil,
            http_method: nil,
            parameters: nil,
            description: nil,
            # Request type
            request_type: nil,
            request_type_markdown: nil,
            request_type_quoted: nil,
            # Response type
            response_type: nil,
            response_type_markdown: nil,
            response_type_quoted: nil,
            response_type_module: nil

  def from_map(name, map) do
    api_name = name
    elixir_name = Macro.underscore(name)

    request_type = map["request"] && Types.type_of(nil, map["request"])
    request_type_markdown = map["request"] && Types.type_to_markdown(request_type)
    request_type_quoted = map["request"] && Types.type_to_quoted(request_type)

    response_type = Types.type_of(nil, map["response"])
    response_type_markdown = Types.type_to_markdown(response_type)
    response_type_quoted = Types.type_to_quoted(response_type)
    response_type_module = Types.type_to_module(response_type)

    parameters = MethodParameters.build(
      map["parameters"],
      map["parameterOrder"]
    )

    raw_description = Map.get(map, "description", "No description")
    description =
      raw_description
      |> String.replace(~r/\.\s+(?=[A-Z])/, fn _full -> ".\n\n" end, global: false)
      |> String.trim()


    %__MODULE__{
      id: map["id"],
      api_name: api_name,
      elixir_name: elixir_name,
      path: map["path"],
      flat_path: map["flatPath"],
      http_method: map["httpMethod"],
      parameters: parameters,
      description: description,
      # Request
      request_type: request_type,
      request_type_markdown: request_type_markdown,
      request_type_quoted: request_type_quoted,
      # Response
      response_type: response_type,
      response_type_markdown: response_type_markdown,
      response_type_quoted: response_type_quoted,
      response_type_module: response_type_module
    }
  end
end
