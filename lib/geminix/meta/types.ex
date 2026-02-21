defmodule Geminix.Meta.Types do
  @moduledoc false

  def represented_as_embed?(type) do
    case type do
      {:ref, _type} -> true
      {:array, {:ref, _type}} -> true
      _other -> false
    end
  end

  def type_of(name, map) do
    case map do
      %{"$ref" => type} ->
        {:ref, type}

      %{"type" => "array", "items" => items_map} ->
        item_type = type_of(name, items_map)
        {:array, item_type}

      %{"type" => "string"} ->
        cond do
          String.ends_with?(name, "_count") ->
            :integer

          String.ends_with?(name, "_time") ->
            :utc_datetime_usec

          true ->
            :string
        end

      %{"type" => "integer"} ->
        :integer

      %{"type" => "number"} ->
        :number

      %{"type" => "boolean"} ->
        :boolean

      %{"type" => "object"} ->
        :map

      %{"type" => "any"} ->
        :any
    end
  end

  def type_to_markdown(type) do
    case type do
      {:ref, type} -> "`t:Geminix.V1beta.#{type}.t/0`"
      {:array, item_type} -> "list of #{type_to_markdown(item_type)}"
      :utc_datetime_usec -> "`t:DateTime.t/0`"
      :string -> "`t:binary/0`"
      :integer -> "`t:integer/0`"
      :number -> "`t:number/0`"
      :boolean -> "`t:boolean/0`"
      :map -> "`t:map/0`"
      :any -> "`t:any/0`"
    end
  end

  def type_to_ecto(name, type) do
    name_atom = String.to_atom(name)

    case type do
      {:ref, type} ->
        quote do
          embeds_one unquote(name_atom),
            unquote(Module.concat(["Geminix.V1beta", type])),
            on_replace: :delete
        end

      {:array, item_type} ->
        case item_type do
          {:ref, inner_type} ->
            quote do
              embeds_many unquote(name_atom),
                unquote(Module.concat(["Geminix.V1beta", inner_type])),
                on_replace: :delete
            end

          :number ->
            quote do
              field unquote(name_atom), {:array, :float}
            end

          _other ->
            quote do
              field unquote(name_atom), {:array, unquote(item_type)}
            end
        end


      :utc_datetime_usec ->
        quote do
          field unquote(name_atom), :utc_datetime_usec
        end

      :string ->
        quote do
          field unquote(name_atom), :string
        end

      :integer ->
        quote do
          field unquote(name_atom), :integer
        end

      :number ->
        quote do
          field unquote(name_atom), :float
        end

      :boolean ->
        quote do
          field unquote(name_atom), :boolean
        end

      :map ->
        quote do
          field unquote(name_atom), :map
        end

      :any ->
        quote do
          field unquote(name_atom), :map
        end
    end
  end

  def type_to_module(type) do
    case type do
      {:ref, type} ->
        Module.concat("Geminix.V1beta", type)

      _other ->
        nil
    end
  end

  def type_to_quoted(type) do
    case type do
      {:ref, type} ->
        quote(do: unquote(Module.concat(["Geminix.V1beta", type])).t())

      {:array, item_type} ->
        quote(do: list(unquote(type_to_quoted(item_type))))

      :utc_datetime_usec ->
        quote(do: DateTime.t())

      :string ->
        quote(do: binary())

      :integer ->
        quote(do: integer())

      :number ->
        quote(do: number())

      :boolean ->
        quote(do: boolean())

      :map ->
        quote(do: map())

      :any ->
        quote(do: any())
    end
  end
end
