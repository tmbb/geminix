defmodule Geminix.Meta.MethodParameters do
  @moduledoc false
  alias Geminix.Meta.MethodParameter

  defstruct ordered: nil,
            unordered: nil

  def build(parameters, parameter_order) do
    params =
      for {name, data} <- parameters do
        MethodParameter.from_map(name, data)
      end

    ordered =
      for param_name <- parameter_order do
        # Quadratic but always N < 10...
        Enum.find(params, fn p -> p.api_name == param_name end)
      end

    unordered = Enum.reject(params, fn p -> p.api_name in parameter_order end)

    %__MODULE__{
      ordered: ordered,
      unordered: unordered
    }
  end
end
