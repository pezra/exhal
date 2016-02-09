defmodule ExHal.Client do

  defstruct headers: []


  def get(url, client, opts \\ %{}) do
    {headers, poison_opts} = figure_headers_and_opt(opts)

    HTTPoison.get(url, headers, poison_opts)
    |> extract_return
  end

  def post(url, body, client, opts \\ %{}) do
    {headers, poison_opts} = figure_headers_and_opt(opts)

    HTTPoison.post(url, body, headers, poison_opts)
    |> extract_return
  end

  defp figure_headers_and_opt(opts) do
    default_opts = %{follow_redirects: true, headers: []}

    {headers, poison_opts} = default_opts
    |> Map.merge(Map.new(opts))
    |> Map.pop(:headers)

    {headers, Keyword.new(poison_opts)}
  end

  defp extract_return(http_resp) do
    case http_resp do
      {:error, err} -> {:error, %ExHal.Error{reason: err.reason} }

      {:ok, resp} -> extract_doc(resp)
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
