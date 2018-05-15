defmodule ExHal.Link do
  @moduledoc """
   A Link is a directed reference from one resource to another resource. They
    are found in the `_links` and `_embedded` sections of a HAL document
  """

  use Expat

  alias ExHal.{Document, NsReg, Trinary, PriestLogic}

  @typedoc """
  A link. Links may be simple or dereferenced (from the embedded section).
  """
  @type t :: %__MODULE__{
    rel: String.t(),
    href: String.t(),
    templated: boolean(),
    name: String.t(),
    target: Document.t()
  }
  defstruct [:rel, :href, :templated, :name, :target]

  @doc """
    Build new link struct from _links entry.
  """
  def from_links_entry(rel, a_map) do
    href = Map.fetch!(a_map, "href")
    templated = Map.get(a_map, "templated", false)
    name = Map.get(a_map, "name", nil)

    %__MODULE__{rel: rel, href: href, templated: templated, name: name}
  end

  @doc """
    Build new link struct from embedded doc.
  """
  def from_embedded(rel, embedded_doc) do
    {:ok, href} = ExHal.url(embedded_doc, fn _doc -> {:ok, nil} end)

    %__MODULE__{rel: rel, href: href, templated: false, target: embedded_doc}
  end

  @doc """
    Returns target url, expanded with `vars` if any are provided.

    Returns `{:ok, "fully_qualified_url"}`
            `:error` if link target is anonymous
  """
  def target_url(a_link, vars \\ %{}) do
    case a_link do
      %{href: nil} ->
        :error

      %{templated: true} ->
        {:ok, UriTemplate.expand(a_link.href, vars)}

      _ ->
        {:ok, a_link.href}
    end
  end

  @doc """
    Returns target url, expanded with `vars` if any are provided.

    Returns `"fully_qualified_url"` or raises exception
  """
  def target_url!(a_link, vars \\ %{}) do
    {:ok, url} = target_url(a_link, vars)

    url
  end

  @doc """
    Expands "curie"d link rels using the namespaces found in the `curies` link.

    Returns `[%Link{}, ...]` a link struct for each possible variation of the input link
  """
  def expand_curie(link, namespaces) do
    NsReg.variations(namespaces, link.rel)
    |> Enum.map(fn rel -> %{link | rel: rel} end)
  end

  def embedded?(link) do
    !!link.target
  end

  @doc """
  **Deprecated**
  See `to_json_map/1`
  """
  def to_json_hash(link), do: to_json_map(link)

  @doc """
  Returns a map that matches the shape of the intended JSON output.
  """
  def to_json_map(link) do
    if embedded?(link) do
      Document.to_json_hash(link.target)
    else
      %{"href" => link.href}
      |> add_templated(link)
      |> add_name(link)
    end
  end

  defpat simple_link(%{target: nil})
  defpat unnamed_link(%{name: nil})
  defpat embedded_link(%{target: %{}})

  @doc """
  Returns true if the links are equivalent.

  Comparison rules:
   - simple links are equal if their hrefs are equal and their names are equal.
   - embedded links are equal if their hrefs are non-nil and equal
   - a simple and an embedded link are equal if their hrefs are equal
  """
  @spec equal?(__MODULE__.t(), __MODULE__.t()) :: boolean()
  def equal?(%{href: nil}, _), do: false
  def equal?(_, %{href: nil}), do: false
  def equal?(link_a = simple_link(), link_b = simple_link())  do
    link_a.rel == link_b.rel
    && link_a.href == link_b.href
      && link_a.name == link_b.name
  end
  def equal?(link_a = embedded_link(), link_b = embedded_link()) do
    # both embedded and href's are comparable
    link_a.rel == link_b.rel
    && link_a.href == link_b.href
  end
  def equal?(link_a = simple_link(), link_b = embedded_link()), do: equal?(link_b, link_a)
  def equal?(link_a = embedded_link(), link_b = simple_link()) do
    # both embedded and href's are comparable
    link_a.rel == link_b.rel
    && link_a.href == link_b.href
  end

  # private functions

  defp add_templated(json_map, %{templated: true}) do
    Map.merge(json_map, %{"templated" => true})
  end

  defp add_templated(json_map, _), do: json_map

  defp add_name(json_map, %{name: name}) when is_binary(name) do
    Map.merge(json_map, %{"name" => name})
  end

  defp add_name(json_map, _), do: json_map
end
