defmodule ExHal.Interpreter do
  @moduledoc """
  Helps to build interpters of HAL documents.

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

  We can define an interpreter for it.

  ```elixir
  defmodule PersonInterpreter do
    use ExHal.Interpreter

    defextract :name
    defextract :address, from: "mailingAddress"
    defextractlink :department_url, rel: "app:department"
  end
  ```

  We can use this interpreter to to extract the pertinent parts of the document into a map.

  ```elixir
  iex> PersonInterpreter.to_params(doc)
  %{name: "Jane Doe",
    address: "123 Main St",
    department_url: "http://example.com/dept/42"}
  ```
  """

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :extractors, accumulate: true, persist: false)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def to_params(doc) do
        Enum.reduce(@extractors, %{}, &apply(__MODULE__, &1, [doc, &2]))
      end
    end
  end

  @doc """
  Define a property extractor.

   * name - the name of the parameter to extract
   * options - Keywords of optional arguments
     - :from - the name of the property in the JSON document. Default is `to_string(name)`.
  """
  defmacro defextract(name, options \\ []) do
    extractor_name = :"extract_#{name}"
    property_name = Keyword.get_lazy(options, :from, fn -> to_string(name) end)

    quote do
      def unquote(extractor_name)(doc, params) do
        extract(params, doc, unquote(name), fn doc ->
          ExHal.get_lazy(doc, unquote(property_name), fn -> :missing end)
        end)
      end

      @extractors unquote(extractor_name)
    end
  end

  @doc """
  Define a link extractor.

   * name - the name of the parameter to extract
   * options - Keywords of optional arguments
     - :rel - the rel or the link in the JSON document. Required.
  """
  defmacro defextractlink(name, options \\ []) do
    extractor_name = :"extract_#{name}"
    rel_name = Keyword.fetch!(options, :rel)

    quote do
      def unquote(extractor_name)(doc, params) do
        extract(params, doc, unquote(name), fn doc ->
          ExHal.link_target_lazy(doc, unquote(rel_name), fn -> :missing end)
        end)
      end

      @extractors unquote(extractor_name)
    end
  end

  def extract(params, doc, param_name, value_extractor) do
    case value_extractor.(doc) do
      :missing -> params
      value -> Map.put(params, param_name, value)
    end
  end
end
