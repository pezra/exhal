defprotocol ExHal.Authorizer do
  @typedoc """
  The value of the `Authorization` header field.
  """
  @type credentials :: String.t()

  @typedoc """
  A URL.
  """
  @type url :: String.t()

  @typedoc """
  An object that implements the ExHal.Authorizer protocol.
  """
  @type authorizer :: any()

  @typedoc """
  Name of a HTTP header field.
  """
  @type header_field_name :: String.t

  @doc """

  Called before each request to calculate any header fields needed to
  authorize the request. A common return would be

      %{"Authorization" => "Bearer <sometoken>"}

  If the URL is unrecognized or no header fields are appropriate or
  needed this function should return and empty map.

  """
  @spec authorization(authorizer, url()) :: %{optional(header_field_name()) => String.t()}
  def authorization(authorizer, url)
end
