defprotocol ExHal.Authorizer do
  @type authorization_field_value :: String.t()
  @type url :: String.t()

  @doc """
  Returns `{:ok, authorization_header_field_value}` if the authorizer
  knows the resource and has credentials for it. Otherwise, returns
  `:no_auth`.
  """
  @spec authorization(any, url()) :: {:ok, authorization_field_value()} | :no_auth
  def authorization(authorizer, url)
end
