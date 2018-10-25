defmodule RequestStubbing do
  defmacro __using__(_) do
    quote do
      use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
      import unquote(__MODULE__)
    end
  end

  defmacro stub_request(method, opts, test) do
    quote do
      use_cassette(
        :stub,
        figure_use_cassette_opts(unquote(method), unquote(opts)),
        do: unquote(test)
      )
    end
  end

  def figure_use_cassette_opts(method, opts) do
    opts = Map.new(opts)

    opts =
      case method do
        "get" -> Map.merge(opts, %{req_body: ""})
        "delete" -> Map.merge(opts, %{req_body: ""})
        _ -> opts
      end

    url = Map.fetch!(opts, :url)

    [
      method: method,
      url: url,
      request_body: Map.fetch!(opts, :req_body),
      body: Map.get(opts, :resp_body, "#{String.upcase(method)} reponse from #{url}"),
      status_code: Map.get(opts, :resp_status, 200)
    ]
  end
end
