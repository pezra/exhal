defmodule ExHal.Document do
  @moduledoc """
    A document is the representaion of a single resource in HAL.
  """

  @opaque t :: %__MODULE__{}

  alias ExHal.{Link, NsReg, Client}

  defstruct properties: %{},
            links: %{},
            client:
              @doc("""
              Returns a new `%ExHal.Document` representing the HAL document provided.
              """)

  def parse(hal_str, client \\ ExHal.client())

  def parse(hal_str, client) when is_binary(hal_str) do
    case Poison.Parser.parse(hal_str) do
      {:ok, parsed} -> {:ok, from_parsed_hal(client, parsed)}
      {:error, reason, _} -> {:error, reason}
      r -> r
    end
  end

  def parse(client, hal_str) do
    parse(hal_str, client)
  end

  @doc """
  Returns a new `%ExHal.Document` representing the HAL document provided.
  """
  def parse!(hal_str, client \\ ExHal.client())

  def parse!(hal_str, client) when is_binary(hal_str) do
    {:ok, doc} = parse(client, hal_str)
    doc
  end

  def parse!(client, hal_str) do
    parse!(hal_str, client)
  end

  @doc """
    Returns a string representation of this HAL document.
  """
  def render!(doc) do
    doc.properties
    |> Map.merge(links_sections_to_json_map(doc))
    |> Poison.encode!()
  end

  @spec from_parsed_hal(%{}) :: __MODULE__.t()
  @spec from_parsed_hal(%{}, Client.t()) :: __MODULE__.t()
  @spec from_parsed_hal(Client.t(), %{}) :: __MODULE__.t()
  @doc """
  Returns new ExHal.Document
  """
  def from_parsed_hal(parsed_hal) do
    from_parsed_hal(parsed_hal, ExHal.client())
  end

  def from_parsed_hal(parsed_hal, %ExHal.Client{} = client) do
    %__MODULE__{
      client: client,
      properties: properties_in(parsed_hal),
      links: links_in(client, parsed_hal)
    }
  end

  def from_parsed_hal(client = %ExHal.Client{}, parsed_hal),
    do: from_parsed_hal(parsed_hal, client)

  @doc """
  Returns true iff the document contains at least one link with the specified rel.
  """
  def has_link?(doc, rel) do
    Map.has_key?(doc.links, rel)
  end

  @doc """
  **Deprecated**

  See to_json_map/1
  """
  def to_json_hash(doc), do: to_json_map(doc)

  @doc """
  Returns a map that matches the shape of the intended JSON output.
  """
  def to_json_map(doc) do
    doc.properties
    |> Map.merge(links_sections_to_json_map(doc))
  end

  @doc """
  Returns `{:ok, <url of specified document>}` or `:error`.
  """
  def url(a_doc, default_fn \\ fn _doc -> :error end) do
    case ExHal.Locatable.url(a_doc) do
      :error -> default_fn.(a_doc)
      url -> url
    end
  end

  # Access

  @doc """
  Fetches value of specified property or links whose `rel` matches

  Returns `{:ok, <property value>}` if `name` identifies a property;
          `{:ok, [%Link{}, ...]}`   if `name` identifies a link;
          `:error`                  othewise
  """
  def fetch(a_document, name) do
    case get_lazy(a_document, name, fn -> :error end) do
      :error -> :error
      result -> {:ok, result}
    end
  end

  @doc """
  Returns the link or property of the specified name, or `default` if
  neither or found.
  """
  def get(a_doc, name, default \\ nil) do
    get_lazy(a_doc, name, fn -> default end)
  end

  @doc """
  Returns link or property of the specified name, or the result of `default_fun`
  if neither are found.
  """
  def get_lazy(a_doc, name, default_fun) do
    get_property_lazy(a_doc, name, fn -> get_links_lazy(a_doc, name, default_fun) end)
  end

  @doc """
  Returns property value when property exists or `default`
  otherwise
  """
  def get_property(a_doc, prop_name, default \\ nil) do
    Map.get_lazy(a_doc.properties, prop_name, fn -> default end)
  end

  @doc """
  Returns `<property value>` when property exists or result of `default_fun`
  otherwise
  """
  def get_property_lazy(a_doc, prop_name, default_fun) do
    Map.get_lazy(a_doc.properties, prop_name, default_fun)
  end

  @doc """
  Returns `[%Link{}...]` when link exists or result of `default` otherwise.
  """
  def get_links(a_doc, link_name, default \\ []) do
    Map.get(a_doc.links, link_name, default)
  end

  @doc """
  Returns `[%Link{}...]` when link exists or result of `default_fun` otherwise.
  """
  def get_links_lazy(a_doc, link_name, default_fun) do
    Map.get_lazy(a_doc.links, link_name, default_fun)
  end

  # Modification

  @doc """
    Add or update a property to a Document.

    Returns new ExHal.Document with the specified property set to the specified value.
  """
  def put_property(doc, name, val) do
    %{doc | properties: Map.put(doc.properties, name, val)}
  end

  @doc """
    Add a link to a Document.

    Returns new ExHal.Document with the specified link.
  """
  def put_link(doc, rel, target, templated \\ false) do
    new_rel_links =
      Map.get(doc.links, rel, []) ++
        [%ExHal.Link{rel: rel, href: target, templated: templated, name: nil}]

    %{doc | links: Map.put(doc.links, rel, new_rel_links)}
  end

  defp links_sections_to_json_map(doc) do
    {embedded, references} =
      doc.links
      |> Map.to_list()
      |> Enum.flat_map(fn {_, v} -> v end)
      |> Enum.split_with(&Link.embedded?(&1))

    %{"_embedded" => render_links(embedded), "_links" => render_links(references)}
  end

  defp render_links(enum) do
    enum
    |> Enum.group_by(& &1.rel)
    |> Map.to_list()
    |> Enum.map(fn {rel, links} -> {rel, Enum.map(links, &Link.to_json_map(&1))} end)
    |> Enum.map(fn {rel, fragments} -> {rel, unbox_single_fragments(fragments)} end)
    |> Map.new()
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
    embedded_links = embedded_links_in(client, parsed_json)

    links =
      simple_links_in(parsed_json)
      |> augment_simple_links_with_embedded_reprs(embedded_links)
      |> backfill_missing_links(embedded_links)
      |> expand_curies(namespaces)

    Enum.group_by(links, fn a_link -> a_link.rel end)
  end

  defp augment_simple_links_with_embedded_reprs(links, embedded_links) do
    links
    |> Enum.map(fn link ->
      case Enum.find(embedded_links, &Link.equal?(&1, link)) do
        nil -> link
        embedded -> %{link | target: embedded.target}
      end
    end)
  end

  defp backfill_missing_links(links, embedded_links) do
    embedded_links
    |> Enum.reduce(links, fn embedded, links ->
      case Enum.any?(links, &Link.equal?(embedded, &1)) do
        false -> [embedded | links]
        _ -> links
      end
    end)
  end

  defp simple_links_in(parsed_json) do
    case Map.fetch(parsed_json, "_links") do
      {:ok, links} -> links_section_to_links(links)
      _ -> []
    end
  end

  defp links_section_to_links(links) do
    Enum.flat_map(links, fn {rel, l} ->
      List.wrap(l)
      |> Enum.filter(& &1["href"])
      |> Enum.map(&Link.from_links_entry(rel, &1))
    end)
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

defimpl ExHal.Locatable, for: ExHal.Document do
  alias ExHal.Link

  def url(a_doc) do
    case ExHal.get_links_lazy(a_doc, "self", fn -> :error end) do
      :error -> :error
      [link | _] -> Link.target_url(link)
    end
  end
end

defimpl Poison.Encoder, for: ExHal.Document do
  alias ExHal.Document

  def encode(doc, options) do
    Poison.Encoder.Map.encode(Document.to_json_map(doc), options)
  end
end
