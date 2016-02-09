
ExHal
=====

[![Build Status](https://travis-ci.org/pezra/exhal.svg?branch=master)](https://travis-ci.org/pezra/exhal) 
[![Hex.pm](https://img.shields.io/hexpm/v/exhal.svg)](https://hex.pm/packages/exhal)

An easy to use [HAL](http://stateless.co/hal_specification.html) API client for elixir.

Usage
----

Consider a resource `http://example.com/hal` whose HAL representation looks like

```json
{ "name": "Hello!",
  "_links": {
     "self"   : { "href": "http://example.com" },
      "profile": [{ "href": "http://example.com/special" },
                  { "href": "http://example.com/normal" }]
  }
}
```

```elixir
iex> doc = ExHal.client
...> |> ExHal.Client.add_headers("User-Agent": "MyClient/1.0")
...> |> ExHal.Client.get("http://example.com/hal")
%ExHal.Document{...}

iex> ExHal.follow_link(doc, "profile")
{:error, %ExHal.Error{reason: "multiple choices"}}

iex> ExHal.follow_link(doc, "nonexistent")
{:error, %ExHal.Error{reason: "no such link"}}

iex> ExHal.follow_link("self")
{:ok, %ExHal.Document{...}}

iex> ExHal.follow_link(doc, "profile", pick_volunteer: true)
{:ok, %ExHal.Document{...}}

iex> ExHal.follow_links(doc, "profile")
[{:ok, %ExHal.Document{...}}, {:ok, %ExHal.Document{...}}]

iex> ExHal.follow_links(doc, "profile", headers: ["Content-Type": "application/vnd.custom.json+type"])
[{:ok, %ExHal.Document{...}}, {:ok, %ExHal.Document{...}}]
```

Installation
----

Add the following to your project `:deps` list:

```elixir
{:exhal, "~>2.0"}
```
