defmodule ExHal.LinkTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias ExHal.Link, as: Link
  alias ExHal.Document, as: Document

  test ".from_links_entry w/ explicit href" do
    link_entry = %{"href" => "http://example.com", "templated" => false, "name" => "test"}
    link = Link.from_links_entry("foo", link_entry)

    assert %Link{href: "http://example.com"} = link
    assert %Link{templated: false} = link
    assert %Link{name: "test"} = link
    assert %Link{rel: "foo"} = link
  end

  test ".from_links_entry w/ templated href" do
    link_entry = %{"href" => "http://example.com{?q}", "templated" => true, "name" => "test"}
    link = Link.from_links_entry("foo", link_entry)

    assert %Link{href: "http://example.com{?q}"} = link
    assert %Link{templated: true} = link
    assert %Link{name: "test"} = link
    assert %Link{rel: "foo"} = link
  end

  test ".from_embedded w/o self link" do
    embedded_doc = Document.from_parsed_hal(ExHal.client(), %{"name" => "foo"})
    link = Link.from_embedded("foo", embedded_doc)

    assert %Link{href: nil} = link
    assert %Link{templated: false} = link
    assert %Link{name: nil} = link
    assert %Link{rel: "foo"} = link
  end

  test ".from_embedded w/ self link" do
    parsed_hal = %{
      "name" => "foo",
      "_links" => %{
        "self" => %{"href" => "http://example.com"}
      }
    }

    embedded_doc = Document.from_parsed_hal(ExHal.client(), parsed_hal)
    link = Link.from_embedded("foo", embedded_doc)

    assert %Link{href: "http://example.com"} = link
    assert %Link{templated: false} = link
    assert %Link{name: nil} = link
    assert %Link{rel: "foo"} = link
  end

  test ".target_url w/ untemplated link w/ vars" do
    assert {:ok, "http://example.com/"} =
             Link.target_url(
               normal_link(),
               %{q: "hello"}
             )
  end

  test ".target_url w/ untemplated link w/o vars" do
    assert {:ok, "http://example.com/"} = Link.target_url(normal_link())
  end

  test ".target_url w/ templated link" do
    assert {:ok, "http://example.com/?q=hello"} =
             Link.target_url(
               templated_link(),
               %{q: "hello"}
             )
  end

  test ".embedded?" do
    assert true == Link.embedded?(%Link{target: %Document{}})
    assert false == Link.embedded?(%Link{href: "https://aa/resource"})
  end

  describe ".equal?/2" do
    test "simple links identical unnamed" do
      link = normal_link("http://example.com/", nil)
      assert Link.equal?(link, link)
    end

    test "simple links diff hrefs" do
      refute Link.equal?(normal_link("abc"), normal_link("xyz"))
    end

    test "simple links diff names" do
      refute Link.equal?(normal_link("abc", "first"), normal_link("abc", "second"))
    end

    test "embedded links identical unnamed" do
      link = embedded_link("http://example.com/")
      assert Link.equal?(link, link)
    end

    test "embedded links diff hrefs" do
      refute Link.equal?(embedded_link("abc"), embedded_link("xyz"))
    end

    test "embedded links anonymous" do
      refute Link.equal?(embedded_link(nil), embedded_link(nil))
    end

    test "embedded links anonymous vs regular" do
      refute Link.equal?(embedded_link(nil), embedded_link())
      refute Link.equal?(embedded_link(), embedded_link(nil))
    end

    test "mixed links equal" do
      assert Link.equal?(
               embedded_link("http://example.com/"),
               normal_link("http://example.com/")
             )

      assert Link.equal?(
               normal_link("http://example.com/"),
               embedded_link("http://example.com/")
             )
    end

    test "mixed links anon" do
      refute Link.equal?(
               embedded_link(nil),
               normal_link("http://example.com/")
             )

      refute Link.equal?(
               normal_link("http://example.com/"),
               embedded_link(nil)
             )
    end
  end

  def normal_link(url \\ "http://example.com/", name \\ "test") do
    link_entry = %{"href" => url, "templated" => false, "name" => name}
    Link.from_links_entry("foo", link_entry)
  end

  def templated_link(tmpl \\ "http://example.com/{?q}") do
    link_entry = %{"href" => tmpl, "templated" => true, "name" => "test"}
    Link.from_links_entry("foo", link_entry)
  end

  def embedded_link(url \\ "http://example.com/embedded") do
    parsed_hal = %{"name" => url, "_links" => %{"self" => %{"href" => url}}}
    target_doc = Document.from_parsed_hal(parsed_hal)

    Link.from_embedded("foo", target_doc)
  end
end
