defmodule ExHal.Document do
  @moduledoc """
    A document is the representaion of a single resource in HAL.
  """

  alias ExHal.Link
  alias ExHal.NsReg

  defstruct properties: %{}, links: %{}, client:

  @doc """
    Returns a new `%ExHal.Document` representing the HAL document provided.
    """
  def parse(client, hal_str) do
    parsed = Poison.Parser.parse!(hal_str)
    from_parsed_hal(client, parsed)
  end

  @doc """
    Returns new ExHal.Document
    """
  def from_parsed_hal(client, parsed_hal) do
    %__MODULE__{client: client,
                properties: properties_in(parsed_hal),
                links: links_in(client, parsed_hal)}
  end

  @doc """
    Returns true iff the document contains at least one link with the specified rel.
    """
  def has_link?(doc, rel) do
    Map.has_key?(doc.links, rel)
  end

  @doc """
    Returns a map that matches the shape of the intended JSON output.
    """
  def to_json_hash(doc) do
    doc.properties
    |> Map.merge(links_sections_to_json_hash(doc))
  end

  defp links_sections_to_json_hash(doc) do
    {embedded, references} = doc.links
    |> Map.to_list
    |> Enum.flat_map(fn ({_,v}) -> v end)
    |> Enum.partition(&(Link.embedded?(&1)))

    %{"_embedded" => render_links(embedded),
      "_links" => render_links(references)}
  end

  defp render_links(enum) do
    enum
    |> Enum.group_by(&(&1.rel))
    |> Map.to_list
    |> Enum.map(fn ({rel, links}) -> {rel, Enum.map(links, &Link.to_json_hash(&1))} end)
    |> Enum.map(fn ({rel, fragments}) -> {rel, unbox_single_fragments(fragments)} end)
    |> Map.new
  end

  defp properties_in(parsed_json) do
    Map.drop(parsed_json, ["_links", "_embedded"])
  end

  defp unbox_single_fragments(fragments) do
    case fragments do
      [fragment] -> fragment
      _ -> fragments
    end
  end

  defp links_in(client, parsed_json) do
    namespaces = NsReg.from_parsed_json(parsed_json)
    raw_links = simple_links_in(parsed_json) ++ embedded_links_in(client, parsed_json)
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
      List.wrap(l) |> Enum.map(&Link.from_links_entry(rel, &1)) end
    )
  end

  defp embedded_links_in(client, parsed_json) do
    case Map.fetch(parsed_json, "_embedded") do
      {:ok, links} -> embedded_section_to_links(client, links)
      _ -> []
    end
  end

  defp embedded_section_to_links(client, links) do
    Enum.flat_map(links, fn {rel, l} ->
      List.wrap(l)
      |> Enum.map(&Link.from_embedded(rel, __MODULE__.from_parsed_hal(client, &1)))
    end)
  end

  defp expand_curies(links, namespaces) do
    Enum.flat_map(links, &Link.expand_curie(&1, namespaces))
  end
end
