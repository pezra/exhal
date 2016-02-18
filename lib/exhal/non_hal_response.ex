defmodule ExHal.NonHalResponse do
  def __struct__ do
    %HTTPoison.Response{}
  end

  def from_httpoison_response(resp) do
    %{resp | __struct__: __MODULE__}
  end
end

defimpl ExHal.Locatable, for: ExHal.NonHalResponse do
  alias ExHal.Link

  def url(a_resp) do
    Keyword.get(a_resp.headers, :Location, :error)
  end
end
