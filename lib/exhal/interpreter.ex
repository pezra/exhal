defmodule ExHal.Interpreter do
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute __MODULE__, :extractors, accumulate: true, persist: false
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def to_params(doc) do
        Enum.reduce(@extractors, %{}, &(apply(__MODULE__, &1, [doc, &2])))
      end
    end
  end

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
