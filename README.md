ExHal
=====

Use [HAL](http://stateless.co/hal_specification.html) APIs with ease.

Usage
----

```elixir

iex> doc = ExHal.parse(~s|
...> { "name": "Hello!",
...>    "_links": {
...>      "self"   : { "href": "http://example.com" },
...>      "profile": [{ "href": "http://example.com/special" },
...>                  { "href": "http://example.com/normal" }]
...>   }
...> }
...> |)
%ExHal.Document{links: %{"profile" => [%ExHal.Link{name: nil, rel: "profile", target: nil,
              target_url: "http://example.com/normal", templated: false},
             %ExHal.Link{name: nil, rel: "profile", target: nil, target_url: "http://example.com/special",
              templated: false}],
            "self" => [%ExHal.Link{name: nil, rel: "self", target: nil, target_url: "http://example.com",
              templated: false}]}, properties: %{"name" => "Hello!"}}
iex> ExHal.url(doc)
{:ok, "http://example.com"}
iex> ExHal.fetch(doc, "name")
{:ok, "Hello!"}
iex> ExHal.fetch(doc, "non-existent")
:error
iex> ExHal.fetch(doc, "profile")
{:ok,
 [%ExHal.Link{name: nil, rel: "profile", target: nil,
              target_url: "http://example.com/normal",
              templated: false},
  %ExHal.Link{name: nil, rel: "profile", target: nil,
              target_url: "http://example.com/special",
              templated: false}]}
iex> ExHal.get_links_lazy(doc, "profile", fn -> [] end)
[%ExHal.Link{name: nil, rel: "profile", target: nil,
             target_url: "http://example.com/normal",
             templated: false},
 %ExHal.Link{name: nil, rel: "profile", target: nil,
             target_url: "http://example.com/special",
             templated: false}]
iex> ExHal.get_links_lazy(doc, "alternate", fn -> [] end)
[]

```


Installation
----

Add the following to your project `:deps` list:

```elixir
{:exhal, "~>1.0"}
```