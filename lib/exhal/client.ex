defmodule ExHal.Client do

  alias ExHal.Document

  defstruct headers: [], opts: [follow_redirects: true]

  def add_headers(client, headers) do
    updated_headers = merge_headers(client.headers, Keyword.new(headers))

    %__MODULE__{client | headers: updated_headers}
  end

  def get(client, url, opts \\ []) do
    {headers, poison_opts} = figure_headers_and_opt(opts, client)

    HTTPoison.get(url, headers, poison_opts)
    |> extract_return(client)
  end

  def post(client, url, body, opts \\ []) do
    {headers, poison_opts} = figure_headers_and_opt(opts, client)

    HTTPoison.post(url, body, headers, poison_opts)
    |> extract_return(client)
  end

  defp figure_headers_and_opt(opts, client) do
    {local_headers, local_opts} = Keyword.pop(Keyword.new(opts), :headers, [])

    headers     = merge_headers(client.headers, local_headers)
    poison_opts = Keyword.merge(client.opts, Keyword.new(local_opts))

    {headers, poison_opts}
  end

  defp merge_headers(old_headers, new_headers) do
    old_headers
    |> Keyword.merge(new_headers, fn (_k,v1,v2) -> List.wrap(v1) ++ List.wrap(v2) end)
  end

  defp extract_return(http_resp, client) do
    case http_resp do
      {:error, err} -> {:error, %ExHal.Error{reason: err.reason} }

      {:ok, resp} -> extract_doc(client, resp)
    end
  end

  defp extract_doc(client, resp) do
    doc  = Document.parse(client, resp.body)
    code = resp.status_code

    cond do
      Enum.member?(200..299, code) -> {:ok, doc}
      true ->  {:error, doc}
    end
  end

end
