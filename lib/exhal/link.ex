defmodule ExHal.Link do
  @moduledoc """
   A Link is a directed reference from one resource to another resource. They
    are found in the `_links` and `_embedded` sections of a HAL document
  """

  alias ExHal.Error, as: Error
  alias ExHal.Document, as: Document

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
  Returns `{:ok, %ExHal.Document{}}`    - representation of the target of the specifyed link
          `{:error, %ExHal.Document{}}` - non-2XX responses that have a HAL body
  """
  def follow(link, vars \\ %{}, headers \\ []) do
    headers = Keyword.new(headers)

    case link do
      %{target: (t = %Document{})} -> {:ok, t}

      _ -> with_url link, vars, fn url ->
          extract_return HTTPoison.get(url, headers, follow_redirect: true)
        end
    end
  end

  @doc """
  Makes a POST request against the target of the link.
  """
  def post(link, body, headers \\ []) do
    headers = Keyword.new(headers)

    with_url link, fn url ->
      extract_return HTTPoison.post(url, body, headers, follow_redirect: true)
    end
  end

  @doc """
    Expands "curie"d link rels using the namespaces found in the `curies` link.

    Returns `[%Link{}, ...]` a link struct for each possible variation of the input link
  """
  def expand_curie(link, namespaces) do
    rel_variations(namespaces, link.rel)
    |> Enum.map(fn rel -> %{link | rel: rel} end)
  end

  defp extract_return(http_resp) do
    case http_resp do
      {:error, err} -> {:error, %ExHal.Error{reason: err.reason} }

      {:ok, resp} -> extract_doc(resp)
    end
  end

  defp with_url(link, tmpl_vars \\ %{}, fun) do
    case target_url(link, tmpl_vars) do
      {:ok, url} -> fun.(url)
      :error -> {:error, %Error{reason: "Unable to determine target url"} }
    end
  end

  defp rel_variations(namespaces, rel) do
    {ns, base} = case String.split(rel, ":", parts: 2) do
                   [ns,base] -> {ns,base}
                   [base]    -> {nil,base}
                 end

    case Map.fetch(namespaces, ns) do
      {:ok, tmpl} -> [rel, UriTemplate.expand(tmpl, rel: base)]
      :error      -> [rel]
    end
  end

  defp extract_doc(resp) do
    doc  = ExHal.parse(resp.body, headers: resp.headers)
    code = resp.status_code

    cond do
      Enum.member?(200..299, code) -> {:ok, doc}
      true ->  {:error, doc}
    end
  end
end
