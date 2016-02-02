ExHal
=====

Use [HAL](http://stateless.co/hal_specification.html) APIs with ease.

Usage
----

```elixir

iex> doc = ExHal.parse(
             ~s|{ "name": "Hello!",
                  "_links": {
                   "self"   : { "href": "http://example.com" },
                   "profile": [{ "href": "http://example.com/special" },
                               { "href": "http://example.com/normal" }]
                 }
               }|
           )
%ExHal.Document{}

iex> ExHal.url(doc)
"http://example.com"

iex> ExHal.fetch(doc, "name")
"Hello!"

iex ExHal.fetch(doc, "non-existent")
:error

iex ExHal.fetch(doc, "profile")
[%ExHal.Link{target_url: "http://example.com/special"},
 %ExHal.Link{target_url: "http://example.com/normal"}]

iex> ExHal.get_links_lazy(doc, "profile", fn -> [] end)
[%ExHal.Link{target_url: "http://example.com/special"},
 %ExHal.Link{target_url: "http://example.com/normal"}]

iex> ExHal.get_links_lazy(doc, "alternate", fn -> [] end)
[]

```


Installation
----

Add the following to your project `:deps` list:

```elixir
{:exhal, "~>1.0"}
```