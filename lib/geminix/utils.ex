defmodule Geminix.Utils do
  @moduledoc false
  def save_to_disk(path, data) do
    File.write!(path, :erlang.term_to_binary(data))
    data
  end

  def load_from_disk(path) do
    path
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  def random_id() do
    1..16
    |> Enum.map(fn _ -> Enum.random(0..255) end)
    |> to_string()
    |> Base.encode16(case: :lower)
  end

  def with_tmp_path(suffix, fun) do
    path = Path.join(System.tmp_dir!(), random_id() <> suffix)
    File.touch!(path)
    try do
      fun.(path)
    after
      File.rm!(path)
    end
  end

  def map_keys_to_snake_case(map) do
    map
    |> Enum.map(fn {k, v} -> {Macro.underscore(k), v} end)
    |> Enum.into(%{})
  end

  def decode_jsonl(text) do
    text
    |> String.split("\n")
    # Reject empty lines, because a valid JSONL file may end in a newline
    |> Enum.reject(fn line -> line == "" end)
    |> Enum.map(&Jason.decode/1)
  end

  def decode_jsonl!(text) do
    Enum.map(decode_jsonl(text), fn {:ok, decoded} -> decoded end)
  end

  def nested_keyword_to_map(keywords) when is_list(keywords) do
    for {key, value} <- keywords, into: %{} do
      new_key =
        key
        |> to_string()
        |> to_camel_case()

      {new_key, nested_keyword_to_map(value)}
    end
  end

  def nested_keyword_to_map(other), do: other

  defp to_camel_case(text) do
    camelized = Macro.camelize(text)
    {first, rest} = String.split_at(camelized, 1)
    String.downcase(first) <> rest
  end

  def full_url(relative) do
    Path.join(
      "https://generativelanguage.googleapis.com/",
      relative
    )
  end

  def handle_errors(response, fun) do
    case response.status do
      200 ->
        case fun.() do
          {:ok, _} = result ->
            result

          {:error, error} ->
            {:error, {:invalid_data, error}}
        end

      _other ->
        {:error, {:bad_request, response}}
    end
  end
end
