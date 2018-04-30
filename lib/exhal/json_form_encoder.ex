defmodule ExHal.JsonFormEncoder do
  @moduledoc """
  Encodes forms into JSON documents.
  """
  alias ExHal.Form

  @spec encode(ExHal.Form.t()) :: String.t()
  @doc """
  Returns a string containing the JSON rendering of the provided form.
  """
  def encode(form) do
    form
    |> Form.get_fields()
    |> Enum.reduce(%{}, fn field, json_thus_far ->
      {:ok, updated_json, _} = JSONPointer.set(json_thus_far, field.path, field.value)
      updated_json
    end)
    |> Poison.encode!()
  end
end
