defmodule ExHal.Transcoder do
  @moduledoc """
    Helps to build transcoders for HAL documents.

    Given a document like

    ```json
    {
      "name": "Jane Doe",
      "mailingAddress": "123 Main St",
      "_links": {
        "app:department": { "href": "http://example.com/dept/42" }
      }
    }
    ```

    We can define an transcoder for it.

    ```elixir
    defmodule PersonTranscoder do
      use ExHal.Transcoder

      defproperty "name"
      defproperty "mailingAddress", param: :address
      deflink     "app:department", param: :department_url
    end
    ```

    We can use this transcoder to to extract the pertinent parts of the document into a map.

    ```elixir
    iex> PersonTranscoder.decode!(doc)
    %{name: "Jane Doe",
      address: "123 Main St",
      department_url: "http://example.com/dept/42"}
    ```
    iex> PersonTranscoder.encode!(%{name: "Jane Doe",
      address: "123 Main St",
      department_url: "http://example.com/dept/42"})
    ~s(
    {
      "name": "Jane Doe",
      "mailingAddress": "123 Main St",
      "_links": {
        "app:department": { "href": "http://example.com/dept/42" }
       }
    } )
    ```
    """

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute __MODULE__, :extractors, accumulate: true, persist: false
      Module.register_attribute __MODULE__, :injectors,  accumulate: true, persist: false

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def decode!(doc) do
        @extractors
        |> Enum.reduce(%{}, &(apply(__MODULE__, &1, [doc, &2])))
      end

      def encode!(params) do
        @injectors
        |> Enum.reduce(%ExHal.Document{}, &(apply(__MODULE__, &1, [&2, params])))
      end
    end
  end

  @doc """
  Define a property extractor and injector.

   * name - the name of the property in HAL
   * options - Keywords arguments
     - :param - the name of the param that maps to this property. Default is `String.to_atom(name)`.
  """
  defmacro defproperty(name, options \\ []) do
    param_name = Keyword.get_lazy(options, :param, fn -> String.to_atom(name) end)
    extractor_name = :"extract_#{param_name}"
    injector_name = :"inject_#{param_name}"

    quote do
      def unquote(extractor_name)(doc, params) do
        extract(params, doc, unquote(param_name), fn doc ->
          ExHal.get_lazy(doc, unquote(name), fn -> :missing end)
        end)
      end
      @extractors unquote(extractor_name)

      def unquote(injector_name)(doc, params) do
        case Map.fetch(params, unquote(param_name)) do
          {:ok, val} -> ExHal.Document.put_property(doc, unquote(name), val)
          :error     -> doc
        end
      end
      @injectors unquote(injector_name)
    end
  end

  @doc """
  Define a link extractor & injector.

   * rel - the rel of the link in HAL
   * options - Keywords arguments
     - :param - the name of the param that maps to this link. Required.
  """
  defmacro deflink(rel, options \\ []) do
    param_name = Keyword.fetch!(options, :param)
    extractor_name = :"extract_#{param_name}"
    injector_name = :"inject_#{param_name}"

    quote do
      def unquote(extractor_name)(doc, params) do
        extract(params, doc, unquote(param_name), fn doc ->
          ExHal.link_target_lazy(doc, unquote(rel), fn -> :missing end)
        end)
      end
      @extractors unquote(extractor_name)

      def unquote(injector_name)(doc, params) do
        case Map.fetch(params, unquote(param_name)) do
          {:ok, target} -> ExHal.Document.put_link(doc, unquote(rel), target)
          :error        -> doc
        end
      end
      @injectors unquote(injector_name)
    end
  end

  def extract(params, doc, param_name, value_extractor) do
    case value_extractor.(doc) do
      :missing -> params
      value -> Map.put(params, param_name, value)
    end
  end
end
