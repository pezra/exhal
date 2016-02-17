defmodule ExHal.Link do
  @moduledoc """
   A Link is a directed reference from one resource to another resource. They
    are found in the `_links` and `_embedded` sections of a HAL document
  """

  alias ExHal.Error
  alias ExHal.Document
  alias ExHal.NsReg
  alias ExHal.Client

  defstruct [:rel, :href, :templated, :name, :target]

  @doc """
    Build new link struct from _links entry.
  """
  def from_links_entry(rel, a_map) do
    href       = Map.fetch!(a_map, "href")
    templated  = Map.get(a_map, "templated", false)
    name       = Map.get(a_map, "name", nil)

    %__MODULE__{rel: rel, href: href, templated: templated, name: name}
  end

  @doc """
    Build new link struct from embedded doc.
  """
  def from_embedded(rel, embedded_doc) do
    {:ok, href} = ExHal.url(embedded_doc, fn (_doc) -> {:ok, nil} end)

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
        {:ok , a_link.href}
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
  Returns `{:ok, %ExHal.Document{}}`    - representation of the target of the specifyed link
          `{:error, %ExHal.Document{}}` - non-2XX responses that have a HAL body
  """
  def follow(link, client, opts \\ %{})  do
    opts      = Map.new(opts)
    tmpl_vars = Map.get opts, :tmpl_vars, %{}
    headers   = Map.get(opts, :headers, []) |> Keyword.new

    case link do
      %{target: (t = %Document{})} -> {:ok, t}

      _ -> with_url link, tmpl_vars, fn url ->
          Client.get(client, url, headers: headers)
        end
    end
  end

  @doc """
  Makes a POST request against the target of the link.
  """
  def post(link, body, client, opts \\ %{headers: []}) do
    opts      = Map.new(opts)
    tmpl_vars = Map.get opts, :tmpl_vars, %{}
    headers   = Map.get(opts, :headers, []) |> Keyword.new

    with_url link, tmpl_vars, fn url ->
      Client.post(client, url, body, headers: headers)
    end
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

  def to_json_hash(link) do
    if embedded?(link) do
      Document.to_json_hash(link.target)
    else
      hash = %{"href" => link.href}
      if !!link.templated, do: hash = Map.merge(hash, %{"templated" => true})
      if !!link.name, do: hash = Map.merge(hash, %{"name" => link.name})
      hash
    end
  end

  defp with_url(link, tmpl_vars, fun) do
    case target_url(link, tmpl_vars) do
      {:ok, url} -> fun.(url)
      :error -> {:error, %Error{reason: "Unable to determine target url"} }
    end
  end

end
