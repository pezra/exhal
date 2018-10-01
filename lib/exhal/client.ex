defmodule ExHal.Client do
  @moduledoc """
  Behavior related to making HTTP requests.

  ## Examples

      iex> ExHal.Client.new()
      ...> |> ExHal.Client.get("http://haltalk.herokuapp.com/")
      %ExHal.Document{...}

      iex> ExHal.Client.new()
      ...> |> ExHal.Client.post("http://haltalk.herokuapp.com/signup", ~s(
      ...>      { "username": "fred",
      ...>        "password": "pwnme",
      ...>        "real_name": "Fred Wilson" }
      ...>     ))
      %ExHal.Document{...}

      iex> authorizer = ExHal.SimpleAuthorizer.new("http://haltalk.herokuapp.com",
      ...>                                         "Bearer my-token")
      iex> ExHal.Client.new()
      ...> |> ExHal.Client.add_headers("Prefer": "minimal")
      ...> |> ExHal.Client.set_authorizer(authorizer)
      %ExHal.Client{...}
  """

  require Logger
  alias ExHal.{Document, NonHalResponse, ResponseHeader, NullAuthorizer}

  @logger Application.get_env(:exhal, :logger, Logger)

  @typedoc """
  Represents a client configuration/connection. Create with `new` function.
  """
  @opaque t :: %__MODULE__{}
  defstruct authorizer: NullAuthorizer.new(),
    headers: [],
    opts: [follow_redirect: true]

  @typedoc """
  The return value of any function that makes an HTTP request.
  """
  @type http_response ::
  {:ok, Document.t | NonHalResponse.t, ResponseHeader.t}
  | {:error, Document.t | NonHalResponse.t, ResponseHeader.t }
  | {:error, Error.t}

  @doc """
  Returns a new client.
  """
  @spec new() :: t
  def new(), do: %__MODULE__{}

  @spec new(Keyword.t) :: t
  def new(headers: headers), do: %__MODULE__{headers: headers, opts: [follow_redirect: true]}
  def new(follow_redirect: follow), do: %__MODULE__{headers: [], opts: [follow_redirect: follow]}
  def new(headers: headers, follow_redirect: follow), do: %__MODULE__{headers: headers, opts: [follow_redirect: follow]}

  # deprecated call patterns
  def new(headers) do
    %__MODULE__{headers: headers, opts: [follow_redirect: true]}
  end

  @spec new(Keyword.t, Keyword.t) :: t
  def new(headers, follow_redirect: follow) do
    new(headers: headers, follow_redirect: follow)
  end

  @doc """
  Returns client that will include the specified headers in any request
   made with it.
  """
  @spec add_headers(t, Keyword.t) :: t
  def add_headers(client, headers) do
    updated_headers = merge_headers(client.headers, headers)

    %__MODULE__{client | headers: updated_headers}
  end

  @doc """
  Returns a client that will authorize requests using the specified authorizer.
  """
  @spec set_authorizer(t, Authorizer.t) :: t
  def set_authorizer(client, new_authorizer) do
    %__MODULE__{client | authorizer: new_authorizer}
  end

  defmacrop log_req(method, url, do: block) do
    quote do
      {time, result} = :timer.tc(fn -> unquote(block) end)
      @logger.debug("#{unquote(method)} <#{unquote(url)}> completed in #{div(time, 1000)}ms")
      result
    end
  end

  @callback get(__MODULE__.t, String.t, Keyword.t) :: http_response()
  def get(client, url, opts \\ []) do
    {headers, poison_opts} = figure_headers_and_opt(opts, client)

    log_req("GET", url) do
      HTTPoison.get(url, headers, poison_opts)
      |> extract_return(client)
    end
  end

  @callback post(__MODULE__.t, String.t, <<>>, Keyword.t) :: http_response()
  def post(client, url, body, opts \\ []) do
    {headers, poison_opts} = figure_headers_and_opt(opts, client)

    log_req("POST", url) do
      HTTPoison.post(url, body, headers, poison_opts)
      |> extract_return(client)
    end
  end

  @callback put(__MODULE__.t, String.t, <<>>, Keyword.t) :: http_response()
  def put(client, url, body, opts \\ []) do
    {headers, poison_opts} = figure_headers_and_opt(opts, client)

    log_req("PUT", url) do
      HTTPoison.put(url, body, headers, poison_opts)
      |> extract_return(client)
    end
  end

  @callback patch(__MODULE__.t, String.t, <<>>, Keyword.t) :: http_response()
  def patch(client, url, body, opts \\ []) do
    {headers, poison_opts} = figure_headers_and_opt(opts, client)

    log_req("PATCH", url) do
      HTTPoison.patch(url, body, headers, poison_opts)
      |> extract_return(client)
    end
  end

  # Private functions

  defp figure_headers_and_opt(opts, client) do
    {local_headers, local_opts} = Keyword.pop(Keyword.new(opts), :headers, [])

    headers = merge_headers(client.headers, local_headers)
    poison_opts = merge_poison_opts(client.opts, local_opts)

    {headers, poison_opts}
  end

  defp merge_headers(old_headers, new_headers) do
    old_headers
    |> Keyword.merge(new_headers, fn _k, v1, v2 -> List.wrap(v1) ++ List.wrap(v2) end)
  end

  @default_poison_opts [follow_redirect: true]
  defp merge_poison_opts(old_opts, new_opts) do
    @default_poison_opts
    |> Keyword.merge(old_opts)
    |> Keyword.merge(Keyword.new(new_opts))
  end

  defp extract_return(http_resp, client) do
    case http_resp do
      {:error, err} -> {:error, %ExHal.Error{reason: err.reason}}
      {:ok, resp} -> interpret_response(client, resp)
    end
  end

  defp interpret_response(client, resp) do
    doc = extract_body_as_doc(client, resp)
    code = resp.status_code

    cond do
      Enum.member?(200..299, code) -> {:ok, doc, %ExHal.ResponseHeader{status_code: code}}
      true -> {:error, doc, %ExHal.ResponseHeader{status_code: code}}
    end
  end

  defp extract_body_as_doc(client, resp) do
    case Document.parse(client, resp.body) do
      {:ok, doc} -> doc
      {:error, _} -> NonHalResponse.from_httpoison_response(resp)
    end
  end
end
