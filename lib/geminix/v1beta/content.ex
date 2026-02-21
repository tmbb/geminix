defmodule Geminix.V1beta.Content do
  use Geminix.Meta.Schema, json: "vendor/v1beta_api.json"

  def from_text(text) when is_binary(text) do
    %__MODULE__{
      parts: [
        %Geminix.V1beta.Part{
          text: text
        }
      ],
      role: "user"
    }
  end
end
