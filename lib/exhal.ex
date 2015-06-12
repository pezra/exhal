defmodule ExHal do
  defmodule Document do
    defstruct properties: %{}, relations: %{}
  end

  defmodule Relation do
    defstruct [:target, :templated, :name]

    def new_from_map(a_map) do
      target = Map.fetch!(a_map, "href")
      templated = Map.get(a_map, "templated", false)
      name = Map.get(a_map, "name", nil)

      %Relation{target: target, templated: templated, name: name}
    end
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
    raw_links = Enum.into(
      Enum.map(links, fn {rel, l} -> {rel, relations_from_links_section_member(l)} end),
      %{}
    )

    decuried_links(raw_links)
  end

  def decuried_links(raw_links) do
    curies = Enum.into(
      Enum.map(Map.get(raw_links, "curies", []), fn it -> {it.name, it.target} end ),
      %{}
    )

    Enum.into(
      Enum.flat_map(
        raw_links, fn {rel, relation} -> Enum.map(rel_variations(curies, rel),
                                                  fn rel -> {rel, relation} end) end
      ),
      %{}
    )
  end

  defp rel_variations(curies, rel) do
    {ns, base} = case String.split(rel, ":", parts: 2) do
                   [ns,base] -> {ns,base}
                   [base]    -> {nil,base}
                 end

    case Map.fetch(curies, ns) do
      {:ok, tmpl} -> [rel, uri_tmpl_expand(tmpl, rel: base)]
      :error      -> [rel]
    end
  end

  # pretends like a generic function but only works for curie templates!
  defp uri_tmpl_expand(tmpl, opts \\ []) do
    String.replace(tmpl, "{rel}", Keyword.fetch!(opts, :rel))
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
    Relation.new_from_map(info)
  end
end
