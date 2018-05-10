defmodule ExHal.NsReg do
  @moduledoc """
  CURIE namespaces for a HAL document.
  """

  defstruct [:namespaces]

  @doc """
    Returns %ExHal.NsReg{}
  """
  def from_parsed_json(parsed_json) do
    curies =
      Map.get(parsed_json, "_links", %{})
      |> Map.get("curies", [])
      |> List.wrap()
      |> Enum.map(fn it -> {Map.get(it, "name"), Map.get(it, "href", "{rel}")} end)
      |> Enum.into(%{})

    %__MODULE__{namespaces: curies}
  end

  @doc """
  Returns list of all valid variations of the specified rel.
  """
  def variations(ns_reg, rel) do
    {ns, base} = parse_curie(rel)

    namespaces = Map.get(ns_reg, :namespaces, %{})

    case Map.fetch(namespaces, ns) do
      {:ok, tmpl} -> [rel, UriTemplate.expand(tmpl, rel: base)]
      :error -> [rel]
    end
  end

  defp parse_curie(rel) do
    case String.split(rel, ":", parts: 2) do
      [ns, base] -> {ns, base}
      [base] -> {nil, base}
    end
  end
end
