defprotocol ExHal.Locatable do
  @spec url(any) :: {:ok, String.t} | :error
  def url(thing)
end
