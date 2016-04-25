defmodule ExHal.Transcoder do
  @moduledoc """
    Helps to build transcoders for HAL documents.

    Given a document like

    ```json
    {
      "name": "Jane Doe",
      "mailingAddress": "123 Main St",
      "_links": {
        "app:department": { "href": "http://example.com/dept/42" },
        "app:manager":    { "href": "http://example.com/people/84" }
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
      deflink     "app:manager",    param: :manager_id, value_converter: PersonUrlConverter
    end
    ```

    `PersonUrlConverter` is a module that has adopted the `ExHal.ValueConverter` behavior.

    ```elixir
    defmodule PersonUrlConverter do
      @behaviour ExHal.ValueConveter

      def from_hal(person_url) do
        to_string(person_url)
        |> String.split("/")
        |> List.last
      end

      def to_hal(person_id) do
        "http://example.com/people/\#{person_id}"
      end
    end
    ```

    We can use this transcoder to to extract the pertinent parts of the document into a map.

    ```elixir
    iex> PersonTranscoder.decode!(doc)
    %{name: "Jane Doe",
      address: "123 Main St",
      department_url: "http://example.com/dept/42",
      manager_id: 84}
    ```
    iex> PersonTranscoder.encode!(%{name: "Jane Doe",
      address: "123 Main St",
      department_url: "http://example.com/dept/42",
      manager_id: 84})
    ~s(
    {
      "name": "Jane Doe",
      "mailingAddress": "123 Main St",
      "_links": {
        "app:department": { "href": "http://example.com/dept/42" },
        "app:manager":    { "href": "http://example.com/people/84" }
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

  defmodule ValueConverter do
    @callback from_hal(any) :: any
    @callback to_hal(any) :: any
  end

  defmodule IdentityConverter do
    @behaviour ValueConverter

    def from_hal(it), do: it
    def to_hal(it), do: it
  end

  @doc """
  Define a property extractor and injector.

   * name - the name of the property in HAL
   * options - Keywords arguments
     - :param - the name of the param that maps to this property. Default is `String.to_atom(name)`.
     - :value_converter - a `ExHal.Transcoder.ValueConverter` with which to convert the value to and from HAL
  """
  defmacro defproperty(name, options \\ []) do
    param_name = Keyword.get_lazy(options, :param, fn -> String.to_atom(name) end)
    value_converter = Keyword.get(options, :value_converter, IdentityConverter)
    extractor_name = :"extract_#{param_name}"
    injector_name = :"inject_#{param_name}"

    quote do
      def unquote(extractor_name)(doc, params) do
        ExHal.get_lazy(doc, unquote(name), fn -> :missing end)
        |> decode_value(unquote(value_converter))
        |> put_param(params, unquote(param_name))
      end
      @extractors unquote(extractor_name)

      def unquote(injector_name)(doc, params) do
        Map.get(params, unquote(param_name), :missing)
        |> encode_value(unquote(value_converter))
        |> put_property(doc, unquote(name))
      end
      @injectors unquote(injector_name)
    end
  end

  @doc """
  Define a link extractor & injector.

   * rel - the rel of the link in HAL
   * options - Keywords arguments
     - :param - the name of the param that maps to this link. Required.
     - :value_converter - a `ExHal.Transcoder.ValueConverter` with which to convert the link target when en/decoding HAL
     - :multiple - output is a list of one or more values
  """
  defmacro deflink(rel, options \\ []) do
    param_name = Keyword.fetch!(options, :param)
    value_converter = Keyword.get(options, :value_converter, IdentityConverter)
    extractor_name = :"extract_#{param_name}"
    injector_name = :"inject_#{param_name}"
    multiple = Keyword.get(options, :multiple, false)

    quote do
      def unquote(extractor_name)(doc, params) do
        case unquote(multiple) do
          false -> ExHal.link_target_lazy(doc, unquote(rel), fn -> :missing end)
          true -> ExHal.link_targets_lazy(doc, unquote(rel), fn -> :missing end)
        end
        |> decode_value(unquote(value_converter))
        |> put_param(params, unquote(param_name))
      end
      @extractors unquote(extractor_name)

      def unquote(injector_name)(doc, params) do
        Map.get(params, unquote(param_name), :missing)
        |> encode_value(unquote(value_converter))
        |> put_link(doc, unquote(rel))
      end
      @injectors unquote(injector_name)
    end
  end

  def decode_value(:missing), do: :missing
  def decode_value(raw_value, converter) do
    converter.from_hal(raw_value)
  end

  def put_param(:missing, params, _), do: params
  def put_param(value, params, param_name) do
    Map.put(params, param_name, value)
  end

  def encode_value(:missing, _), do: :missing
  def encode_value(raw_value, converter) do
    converter.to_hal(raw_value)
  end

  def put_link(:missing, doc, _), do: doc
  def put_link(target, doc, rel) do
    ExHal.Document.put_link(doc, rel, target)
  end

  def put_property(:missing, doc, _), do: doc
  def put_property(value, doc, prop_name) do
    ExHal.Document.put_property(doc, prop_name, value)
  end
end
