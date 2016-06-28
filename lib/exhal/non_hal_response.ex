defmodule ExHal.NonHalResponse do
  defstruct status_code: nil, body: nil, headers: []

  def from_httpoison_response(resp) do
    %{resp | __struct__: __MODULE__}
  end
end

defimpl ExHal.Locatable, for: ExHal.NonHalResponse do
  def url(a_resp) do
    a_resp.headers
    |> Enum.find({nil, :error},
      fn {field_name, _} -> Regex.match?(~r/(content-)?location/i, field_name) end)
    |> (fn {_,url} -> url end).()
  end
end
