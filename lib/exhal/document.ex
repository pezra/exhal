defmodule ExHal.Document do
  @moduledoc """
    A document is the representaion of a single resource in HAL.
  """

  alias ExHal.Link, as: Link

  defstruct properties: %{}, links: %{}

  @doc """
  Returns new ExHal.Document
  """
  def from_parsed_hal(parsed_hal) do
    %__MODULE__{properties: properties_in(parsed_hal), links: links_in(parsed_hal)}
  end


  defp properties_in(parsed_json) do
    Map.drop(parsed_json, ["_links", "_embedded"])
  end

  defp links_in(parsed_json) do
    namespaces = extract_namespaces(parsed_json)
    raw_links = simple_links_in(parsed_json) ++ embedded_links_in(parsed_json)
    links = expand_curies(raw_links, namespaces)

    Enum.group_by(links, fn a_link -> a_link.rel end )
  end

  defp simple_links_in(parsed_json) do
    case Map.fetch(parsed_json, "_links") do
      {:ok, links} -> links_section_to_links(links)
      _ -> []
    end
  end

  defp links_section_to_links(links) do
    Enum.flat_map(links, fn {rel, l} ->
      Enum.map(listify(l), &Link.from_links_entry(rel, &1)) end
    )
  end

  defp embedded_links_in(parsed_json) do
    case Map.fetch(parsed_json, "_embedded") do
      {:ok, links} -> embedded_section_to_links(links)
      _ -> []
    end
  end

  defp embedded_section_to_links(links) do
    Enum.flat_map(links, fn {rel, l} ->
      Enum.map(listify(l), &Link.from_embedded(rel, __MODULE__.from_parsed_hal(&1))) end
    )
  end

  defp extract_namespaces(parsed_hal) do
    links = Dict.get(parsed_hal, "_links", %{})
    curies = Dict.get(links, "curies", []) |> listify

    Enum.map(curies,
      fn it -> {Dict.get(it, "name"), Dict.get(it, "href", "{rel}")} end
    )
    |> Enum.into(%{})
  end

  defp expand_curies(links, namespaces) do
    Enum.flat_map(links, &Link.expand_curie(&1, namespaces))
  end

  defp listify(link_entry) when is_map(link_entry) do
    [link_entry]
  end

  defp listify(link_entry) when is_list(link_entry) do
    link_entry
  end

end