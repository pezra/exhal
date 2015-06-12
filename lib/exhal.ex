defmodule ExHal do
  defmodule Document do
    defstruct properties: %{}, relations: %{}
  end

  defmodule Relation do
    defstruct [:target, :templated]
  end

  def parse hal_str do
    parsed = Poison.Parser.parse!(hal_str)
    %ExHal.Document{properties: properties_in(parsed), relations: relations_in(parsed)}
  end

  def fetch(a_document, name) do
    case Map.fetch(a_document.properties, name) do
      :error   -> Map.fetch(a_document.relations, name)
      prop_val -> prop_val
    end
  end

  defp properties_in(parsed_json) do
    Map.drop(parsed_json, ["_links"])
  end

  defp relations_in(parsed_json) do
    case Map.fetch(parsed_json, "_links") do
      {:ok, links} -> links_section_to_relations(links)
      _ -> %{}
    end
  end

  defp links_section_to_relations(links) do
    Enum.into(
      Enum.map(links, fn {rel, l} -> {rel, relations_from_links_section_member(l)} end),
      %{}
    )
  end

  defp relations_from_links_section_member(link_infos) when is_map(link_infos) do
    [relation_from_link_info(link_infos)]
  end

  defp relations_from_links_section_member(link_infos) when is_list(link_infos) do
    Enum.map(link_infos, fn x -> relation_from_link_info(x) end)
  end

  defp relations_from_links_section_member(nil) do
    []
  end

  defp relation_from_link_info(info) do
    target = Map.fetch!(info, "href")
    templated = Map.get(info, "templated", false)

    %Relation{target: target, templated: templated}
  end
end
