defmodule ExHal do
  defmodule Document do
    defstruct properties: %{}, relations: %{}
  end

  defmodule Relation do
    defstruct [:target, :templated, :name]

    @doc """
      Build new relation.
    """
    def from_map(a_map) do
      target = Map.fetch!(a_map, "href")
      templated = Map.get(a_map, "templated", false)
      name = Map.get(a_map, "name", nil)

      %Relation{target: target, templated: templated, name: name}
    end
  end

  @doc """
  Returns a new `%ExHal.Document` representing the HAL document provided.
  """
  def parse hal_str do
    parsed = Poison.Parser.parse!(hal_str)
    %ExHal.Document{properties: properties_in(parsed), relations: relations_in(parsed)}
  end

  @doc """
  Fetches value of specified property or links whose `rel` matches

  Returns `{:ok, <property value>}` if `name` identifies a property;
          `{:ok, [<relation>, ...]}` if `name` identifies a link;
          `:error` othewise
  """
  def fetch(a_document, name) do
    case Map.fetch(a_document.properties, name) do
      :error  -> Map.fetch(a_document.relations, name)
      results -> results
    end
  end

  @doc """
  Fetches expanded version of all templated links with `rel` matching
  `name`. For compatibility sake if no relations are found `name` will be used
  to look properties.

  Returns `{:ok, [<relation with expanded target>, ...]}` if `name` identifies a link;
          `{:ok, <property value>}` if `name` identifies a property;
          `:error` othewise
  """
  def fetch(a_document, name, vars) do
    case Map.fetch(a_document.relations, name) do
      :error ->  Map.fetch(a_document.properties, name)
      {:ok, results} -> { :ok, results |>
                           Enum.map fn r ->
                             %{r | target: UriTemplate.expand(r.target, vars)}
                           end }
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

  defp decuried_links(raw_links) do
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
      {:ok, tmpl} -> [rel, UriTemplate.expand(tmpl, rel: base)]
      :error      -> [rel]
    end
  end

  defp relations_from_links_section_member(link_info) when is_map(link_info) do
    [Relation.from_map(link_info)]
  end

  defp relations_from_links_section_member(link_infos) when is_list(link_infos) do
    Enum.map link_infos, &Relation.from_map/1
  end

  defp relations_from_links_section_member(nil) do
    []
  end
end
