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

  defmacro defextract(name) do
    extractor_name = :"extract_#{name}"

    quote do
      def unquote(extractor_name)(doc, params) do
        value = ExHal.get_lazy(doc, unquote(to_string(name)), fn -> nil end)
        Map.put(params, unquote(name), value)
      end

      @extractors unquote(extractor_name)
    end
  end
end
