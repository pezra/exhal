
ExHal
=====

[![Build Status](https://travis-ci.org/pezra/exhal.svg?branch=master)](https://travis-ci.org/pezra/exhal) 
[![Hex.pm](https://img.shields.io/hexpm/v/exhal.svg)](https://hex.pm/packages/exhal)

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

ExHal can also make requests. Continuing the example above:

```elixir
ExHal.follow_link(doc, "profile")
{:error, %ExHal.Error{reason: "multiple choices"}}

ExHal.follow_link(doc, "nonexistent")
{:error, %ExHal.Error{reason: "no such link"}}

ExHal.follow_link("self")
{:ok, %ExHal.Document{...}}

ExHal.follow_link(doc, "profile", pick_volunteer: true)
{:ok, %ExHal.Document{...}}

ExHal.follow_links(doc, "profile")
[{:ok, %ExHal.Document{...}}, {:ok, %ExHal.Document{...}]

```

Installation
----

Add the following to your project `:deps` list:

```elixir
{:exhal, "~>1.0"}
```