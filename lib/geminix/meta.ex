defmodule Geminix.Meta do
  @moduledoc false

  alias Geminix.Meta.Schema
  alias Geminix.Meta.Method

  import NimbleParsec

  required_parameter =
    string("{")
    # ?} == 125
    |> ascii_string([not: 125], min: 1)
    |> string("}")
    |> replace(:param)

  url =
    repeat(
      choice([
        required_parameter,
        # ?{ == 123
        ascii_string([not: 123], min: 1)
      ])
    )
    |> optional(ascii_string([not: 123], min: 1))

  defparsec(:flat_path_parser, url)

  def parse_flat_path!(path) do
    case flat_path_parser(path) do
      {:ok, result, "", _, _, _} ->
        result
    end
  end

  def flat_path_with_params!(flat_path, positional_params) do
    parsed_url = parse_flat_path!(flat_path)

    case :param in parsed_url do
      true ->
        {reversed_parts, []} =
          Enum.reduce(parsed_url, {_parts = [], positional_params}, fn part, {parts, all_params} ->
            case {part, all_params} do
              {:param, [param | params]} ->
                new_part = quote(do: to_string(unquote(param)))
                {[new_part | parts], params}

              {bin, params} when is_binary(bin) ->
                {[part | parts], params}
            end
          end)

        parts = Enum.reverse(reversed_parts)

        quoted =
          quote do
            Enum.join(unquote(parts))
          end

        {:has_params, quoted}

      false ->
        :no_params
    end
  end

  require EEx

  @external_resource "lib/geminix/meta/templates/schema_moduledoc.md.eex"

  EEx.function_from_file(
    :defp,
    :render_schema_moduledoc,
    "lib/geminix/meta/templates/schema_moduledoc.md.eex",
    [:assigns]
  )

  # -------------------------------------
  # Resources
  # -------------------------------------

  def create_resource_modules(api_data) do
    for {resource_name, resource_data} <- api_data["resources"] do
      resource_module_name =
        Module.concat(
          Geminix.V1beta,
          Macro.camelize(resource_name)
        )

      methods =
        for {name, map} <- resource_data["methods"] do
          Method.from_map(name, map)
        end

      create_resource_module(resource_module_name, methods)
    end
  end

  def create_resource_module(module_name, methods) do
    definitions_with_errors =
      for method <- methods,
          not is_nil(method.response_type),
          not is_nil(method.response_type_module) do
        create_method_definition(method)
      end

    definitions =
      definitions_with_errors
      |> Enum.filter(fn r -> match?({:ok, _definition}, r) end)
      |> Enum.map(fn {:ok, definition} -> definition end)

    contents =
      quote do
        import Geminix.Cache, only: [defcached: 2]
        unquote(definitions)
      end

    Module.create(module_name, contents, Macro.Env.location(__ENV__))
  end

  def create_method_definition(%Method{} = method) do
    positional_arguments =
      for p <- method.parameters.ordered do
        Macro.var(String.to_atom(p.elixir_name), __MODULE__)
      end

    case flat_path_with_params!(method.flat_path, positional_arguments) do
      :no_params ->
        all_positional_arguments = positional_arguments ++ [Macro.var(:request, __MODULE__)]

        positional_types =
          for p <- method.parameters.ordered do
            p.type_quoted
          end

        all_positional_types = positional_types ++ [method.request_type_quoted]

        function_name = String.to_atom(method.elixir_name)

        _definition =
          quote do
            @doc unquote(method.description)

            @spec unquote(function_name)(
                    unquote_splicing(all_positional_types),
                    keyword()
                  ) :: {:ok, unquote(method.response_type_quoted)} |
                      {:error, {:invalid_data, Ecto.Changeset.t()}} |
                      {:error, {:bad_request, Req.Response.t()}}

            def unquote(function_name)(unquote_splicing(all_positional_arguments), opts \\ []) do
              _ = opts
              _ = unquote(all_positional_arguments)
              raise "Not implemented"
            end
          end

        :error

      {:has_params, quoted} ->
        all_positional_arguments = positional_arguments ++
          [Macro.var(:request, __MODULE__)]

        positional_types =
          for p <- method.parameters.ordered do
            p.type_quoted
          end

        all_positional_types = positional_types ++
          [method.request_type_quoted]

        function_name = String.to_atom(method.elixir_name)

        args_without_defaults =
          for arg <- all_positional_arguments do
            case arg do
              {:\\, _meta, [arg_var, _arg_value]} ->
                arg_var

              other ->
                other
            end
          end

        result =
          case method.http_method do
            "POST" ->
              body =
                quote do
                  api_key = Geminix.Config.fetch_api_key!(opts)
                  plug = Geminix.Config.get_plug(opts)
                  url = Geminix.Utils.full_url(unquote(quoted))

                  req = Req.new(
                    method: :post,
                    url: url,
                    headers: [
                      {"x-goog-api-key", api_key},
                      {"content-type", "application/json"}
                    ],
                    body: Jason.encode_to_iodata!(request)
                  )

                  response =
                    Req.post!(
                      req,
                      plug: plug,
                      receive_timeout: Geminix.Config.default_receive_timeout()
                    )

                  Geminix.Utils.handle_errors(response, fn ->
                    unquote(method.response_type_module).from_map(response.body)
                  end)
                end

              {:ok, body}

            _other ->
              :error
          end

        case result do
          :error ->
            :error

          {:ok, body} ->
            definition =
              quote do
                @doc unquote(method.description)

                @spec unquote(function_name)(
                        unquote_splicing(all_positional_types),
                        keyword()
                      ) :: {:ok, unquote(method.response_type_quoted)} |
                          {:error, {:invalid_data, Ecto.Changeset.t()}} |
                          {:error, {:bad_request, Req.Response.t()}}

                def unquote(function_name)(
                      unquote_splicing(all_positional_arguments),
                      opts \\ []
                    ) do
                  # Pop the cache-related argument from the options
                  {ignore_cache, opts} = Geminix.Config.pop_ignore_cache(opts, false)
                  use_cache = not ignore_cache
                  # Repackage the arguments in a list to be used as the cache key
                  args = [unquote_splicing(args_without_defaults), opts]
                  # Run the function, possibly with cached responses
                  Geminix.Cache.tagged_anonymous_function_with_cache(
                    use_cache,
                    {__MODULE__, unquote(function_name), args},
                    fn -> unquote(body) end
                  )
                end
              end

            {:ok, definition}
        end
    end
  end

  # -------------------------------------
  # Schemas
  # -------------------------------------

  @manual_schemas [
    "BatchGenerateContentRequest",
    "AsyncBatchEmbedContentRequest",
    "File",
    "GenerateContentRequest",
    "GenerateContentResponse",
    "Content"
  ]

  def create_schema_modules(api_data) do
    version = api_data["version"] |> Macro.camelize()

    schemas =
      for {schema_name, schema_data} <- api_data["schemas"],
          schema_name not in @manual_schemas do
        Schema.from_map(schema_data)
      end

    Enum.map(schemas, fn s -> create_schema_module(version, s) end)
  end

  def create_schema_module(version, schema) do
    module_name = Module.concat(["Geminix", version, schema.id])
    contents = Schema.schema_module_contents(version, schema)
    Module.create(module_name, contents, Macro.Env.location(__ENV__))
  end

  # -------------------------------------
  # Documentation helpers
  # -------------------------------------
  defp get_schema_modules(api_data) do
    version = api_data["version"] |> Macro.camelize()

    modules =
      for {_schema_name, schema_data} <- api_data["schemas"] do
        schema = Schema.from_map(schema_data)
        Module.concat(["Geminix", version, schema.id])
      end

    modules
  end

  def create_json_group_for_modules_file(src_path, dst_path) do
    api_data =
      src_path
      |> File.read!()
      |> Jason.decode!()

    schema_modules = get_schema_modules(api_data)

    resource_modules = [
        Geminix.V1beta.Batches,
        Geminix.V1beta.Models,
        Geminix.V1beta.TunedModels,
        Geminix.V1beta.Dynamic,
        Geminix.V1beta.CachedContents,
        # Geminix.V1beta.Media,
        Geminix.V1beta.Files,
        Geminix.V1beta.GeneratedFiles,
        Geminix.V1beta.FileSearchStores,
        Geminix.V1beta.Corpora
      ]

    data = [
      %{
        name: "V1beta - Resources",
        modules: Enum.map(resource_modules, &inspect/1)
      },
      %{
        name: "V1beta - Schemas",
        modules: Enum.map(schema_modules, &inspect/1)
      }
    ]

    File.write!(dst_path, Jason.encode!(data, pretty: true))
  end
end
