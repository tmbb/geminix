defmodule Geminix.V1beta.GenerateContentResponse do
  use Geminix.Meta.Schema, json: "vendor/v1beta_api.json"

  @doc """
  Extract the text from a response.
  """
  @spec extract_text(t()) :: {:ok, binary()} | :error
  def extract_text(response) do
    case response.candidates do
      [candidate | _candidates] ->
        parts = candidate.content.parts

        text =
          parts
          |> Enum.map(&part_to_text/1)
          |> Enum.join("\n")

        {:ok, text}

      _other ->
        :error
    end
  end

  @doc """
  Extract the text from a response.
  """
  @spec extract_text!(t()) :: binary()
  def extract_text!(response) do
    {:ok, text} = extract_text(response)
    text
  end

  defp part_to_text(%Geminix.V1beta.Part{text: text}), do: text
  defp part_to_text(_other), do: ""

  @doc false
  def simple_request(opts) do
    model = Keyword.get(opts, :model)
    instruction = Keyword.fetch!(opts, :instruction)
    system_instruction = Keyword.get(opts, :system_instruction)
    response_schema = Keyword.get(opts, :response_schema)

    default_response_mime_type =
      case response_schema do
        nil -> nil
        _other -> "application/json"
      end

    response_mime_type =
      Keyword.get(
        opts,
        :response_mime_type,
        default_response_mime_type
      )

    contents = [
      %Geminix.V1beta.Content{
        parts: [
          %Geminix.V1beta.Part{
            text: instruction
          }
        ],
        role: "user"
      }
    ]

    system_instruction_content =
      if system_instruction do
        %Geminix.V1beta.Content{
          parts: [
            %Geminix.V1beta.Part{
              text: system_instruction
            }
          ],
          role: "user"
        }
      else
        nil
      end

    %Geminix.V1beta.GenerateContentRequest{
      model: model,
      contents: contents,
      system_instruction: system_instruction_content,
      generation_config: %Geminix.V1beta.GenerationConfig{
        response_mime_type: response_mime_type
      }
    }
  end
end
