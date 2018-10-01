defprotocol ExHal.Authorizer do
  @typedoc """
  The value of the `Authorization` header field.
  """
  @type credentials :: String.t()

  @typedoc """
  A URL.
  """
  @type url :: String.t()

  @doc """
  Returns `{:ok, credentials}` if the authorizer
  knows the resource and has credentials for it. Otherwise, returns
  `:no_auth`.
  """
  @spec authorization(any, url()) :: {:ok, credentials()} | :no_auth
  def authorization(authorizer, url)
end
