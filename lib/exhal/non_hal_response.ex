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
    a_resp.headers
    |> Enum.find({nil, :error},
      fn {field_name, value} -> Regex.match?(~r/(content-)?location/i, field_name) end)
    |> (fn {_,url} -> url end).()
  end
end
