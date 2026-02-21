defmodule Geminix.Meta.Schema do
  @moduledoc false

  alias Geminix.Meta.Types
  alias Geminix.Meta.SchemaProperty
  require EEx

  defstruct id: nil,
            description: nil,
            type: nil,
            properties: nil,
            extras: nil

  @external_resource "lib/geminix/meta/templates/schema_moduledoc.md.eex"

  EEx.function_from_file(
    :defp,
    :render_schema_moduledoc,
    "lib/geminix/meta/templates/schema_moduledoc.md.eex",
    [:assigns]
  )

  defmacro __using__(opts) do
    module = __CALLER__.module
    schema_name = module |> Module.split() |> List.last()

    json_path = Keyword.fetch!(opts, :json)
    api_data =
      json_path
      |> File.read!()
      |> Jason.decode!()

    version = Macro.camelize(api_data["version"])
    schema_map = api_data["schemas"][schema_name]

    schema = from_map(schema_map)

    schema_module_contents(version, schema)
  end

  def from_map(map) do
    raw_properties = Map.get(map, "properties")

    properties =
      case raw_properties do
        %{} -> SchemaProperty.from_property_map(raw_properties)
        _other -> nil
      end

    %__MODULE__{
      id: Map.fetch!(map, "id"),
      description: map["description"],
      type: Map.fetch!(map, "type"),
      properties: properties
    }
  end

  def schema_module_contents(version, schema) do
    module_name = Module.concat(["Geminix", version, schema.id])
    table_name = Macro.underscore(schema.id)

    non_embed_fields =
      schema.properties
      |> Enum.reject(fn p -> Types.represented_as_embed?(p.type) end)
      |> Enum.map(fn p -> String.to_atom(p.elixir_name) end)

    embed_fields =
      schema.properties
      |> Enum.filter(fn p -> Types.represented_as_embed?(p.type) end)
      |> Enum.map(fn p -> String.to_atom(p.elixir_name) end)

    fields =
      for p <- schema.properties do
        p.ecto_field
      end

    field_types =
      Enum.map(schema.properties, fn p ->
        key = String.to_atom(p.elixir_name)
        type = p.quoted_type

        {key, type}
      end)

    moduledoc = render_schema_moduledoc(schema: schema)

    inner_changeset_body =
      quote do
        cast(schema, params, unquote(non_embed_fields))
      end

    changeset_body =
      Enum.reduce(embed_fields, inner_changeset_body, fn next, body ->
        quote do
          unquote(body)
          |> cast_embed(unquote(next))
        end
      end)

    quote do
      @moduledoc unquote(moduledoc)

      use Ecto.Schema
      import Ecto.Changeset

      @primary_key false

      @type t() :: %__MODULE__{unquote_splicing(field_types)}

      @derive {Inspect, except: [:__meta__]}

      schema unquote(table_name) do
        unquote(fields)
      end

      @doc false
      def changeset(schema, params \\ %{}) do
        params = Geminix.Utils.map_keys_to_snake_case(params)
        unquote(changeset_body)
      end

      @doc """
      Create a `t:#{unquote(inspect(module_name))}.t/0` from a map returned
      by the Gemini API.

      Sometimes, this function should not be applied to the full response body,
      but instead it should be applied to the correct part of the map in the
      response body.
      This depends on the concrete API call.
      """
      @spec from_map(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
      def from_map(schema \\ %__MODULE__{}, map) do
        changes = changeset(schema, map)
        apply_action(changes, :create)
      end

      # Extra functions defined manually
      unquote(schema.extras)

      defimpl Jason.Encoder do
        def encode(value, opts) do
          value
          |> Map.from_struct()
          # We don't want to encode this key
          |> Map.delete(:__meta__)
          # We also don't want to encode any key that is `nil`.
          # This is a convention the Gemini API follows, even though
          # it's not spelled out explicitly.
          |> Map.reject(fn {_k, v} -> is_nil(v) end)
          |> Jason.Encode.map(opts)
        end
      end
    end
  end
end
