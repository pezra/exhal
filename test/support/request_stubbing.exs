defmodule RequestStubbing do
  defmacro __using__(_) do
    quote do
      use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
      import unquote(__MODULE__)
    end
  end

  defmacro stub_request(method, opts, test) do
    quote do
      use_cassette(:stub,
                   figure_use_cassette_opts(unquote(method), unquote(opts)),
                   do: unquote(test))
    end
  end

  def figure_use_cassette_opts(method, opts) do
    opts = Map.new(opts)
    url = Map.fetch!(opts, :url)
    if method == "get", do: opts = Map.merge(opts, %{req_body: ""})

    [method:       method,
     url:          url,
     request_body: Map.fetch!(opts, :req_body),
     body:         Map.get(opts, :resp_body, "#{String.upcase(method)} reponse from #{url}"),
     status_code:  Map.get(opts, :resp_status, 200)
    ]
  end
end
