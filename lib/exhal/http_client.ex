defmodule ExHal.HttpClient do
  @callback get(String.t, HTTPoison.Base.headers, Keyword.t) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} |
  {:error, HTTPoison.Error.t}
  @callback post(String.t, any, HTTPoison.Base.headers, Keyword.t) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} |
  {:error, HTTPoison.Error.t}
  @callback put(String.t, any, HTTPoison.Base.headers, Keyword.t) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} |
  {:error, HTTPoison.Error.t}
  @callback patch(String.t, any, HTTPoison.Base.headers, Keyword.t) :: {:ok, HTTPoison.Response.t | HTTPoison.AsyncResponse.t} |
  {:error, HTTPoison.Error.t}
end