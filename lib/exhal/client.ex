defmodule ExHal.Client do

  require Logger
  alias ExHal.Document
  alias ExHal.NonHalResponse

  defstruct headers: [], opts: [follow_redirect: true]

  def add_headers(client, headers) do
    updated_headers = merge_headers(client.headers, Keyword.new(headers))

    %__MODULE__{client | headers: updated_headers}
  end

  defmacrop log_req(method, url, do: block) do
    quote do
      {time, result} = :timer.tc(fn -> unquote(block) end)
      Logger.debug "#{unquote(method)} <#{unquote(url)}> completed in #{time}ms"
      result
    end
  end

  def get(client, url, opts \\ []) do
    {headers, poison_opts} = figure_headers_and_opt(opts, client)

    log_req("GET", url) do
      HTTPoison.get(url, headers, poison_opts)
      |> extract_return(client)
    end
  end

  def post(client, url, body, opts \\ []) do
    {headers, poison_opts} = figure_headers_and_opt(opts, client)

    log_req("POST", url) do
      HTTPoison.post(url, body, headers, poison_opts)
      |> extract_return(client)
    end
  end

  def put(client, url, body, opts \\ []) do
    {headers, poison_opts} = figure_headers_and_opt(opts, client)

    log_req("PUT", url) do
      HTTPoison.put(url, body, headers, poison_opts)
      |> extract_return(client)
    end
  end

  def patch(client, url, body, opts \\ []) do
  {headers, poison_opts} = figure_headers_and_opt(opts, client)

    log_req("PATCH", url) do
      HTTPoison.patch(url, body, headers, poison_opts)
      |> extract_return(client)
    end
  end

  defp figure_headers_and_opt(opts, client) do
    {local_headers, local_opts} = Keyword.pop(Keyword.new(opts), :headers, [])

    headers     = merge_headers(client.headers, local_headers)
    poison_opts = merge_poison_opts(client.opts, local_opts)

    {headers, poison_opts}
  end

  defp merge_headers(old_headers, new_headers) do
    old_headers
    |> Keyword.merge(new_headers, fn (_k,v1,v2) -> List.wrap(v1) ++ List.wrap(v2) end)
  end

  @default_poison_opts [follow_redirect: true]
  defp merge_poison_opts(old_opts, new_opts) do
    @default_poison_opts
    |> Keyword.merge(old_opts)
    |> Keyword.merge(Keyword.new(new_opts))
  end

  defp extract_return(http_resp, client) do
    case http_resp do
      {:error, err} -> {:error, %ExHal.Error{reason: err.reason} }

      {:ok, resp} -> interpret_response(client, resp)
    end
  end

  defp interpret_response(client, resp) do
    doc = extract_body_as_doc(client, resp)
    code = resp.status_code

    cond do
      Enum.member?(200..299, code) -> {:ok, doc, %ExHal.ResponseHeader{status_code: code}}
      true ->  {:error, doc, %ExHal.ResponseHeader{status_code: code}}
    end
  end

  defp extract_body_as_doc(client, resp) do
    case Document.parse(client, resp.body) do
      {:ok, doc} -> doc
      {:error, _} -> NonHalResponse.from_httpoison_response(resp)
    end
  end

end
