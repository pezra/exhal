defprotocol ExHal.Locatable do
  @fallback_to_any true

  @spec url(any) :: {:ok, String.t()} | :error
  def url(thing)
end

defimpl ExHal.Locatable, for: Any do
  def url(thing), do: raise(ArgumentError, "#{thing.inspect} is not `Locatable`")
end
