defmodule YoutubeLister.CSVTest do
  use ExUnit.Case, async: true

  alias YoutubeLister.{CSV, Video}

  defp video(id, date, opts \\ []) do
    %Video{
      id: id,
      title: opts[:title] || "Title #{id}",
      url: Video.url_for(id),
      published: date,
      views: Keyword.get(opts, :views, 1),
      likes: Keyword.get(opts, :likes, 1)
    }
  end

  describe "sort_newest_first/1" do
    test "orders by publication date, newest first" do
      a = video("a", "2024-01-01T00:00:00Z")
      b = video("b", "2024-03-01T00:00:00Z")
      c = video("c", "2024-02-01T00:00:00Z")

      assert ["b", "c", "a"] == CSV.sort_newest_first([a, b, c]) |> Enum.map(& &1.id)
    end

    test "videos with no publish date sort last" do
      a = video("a", "2024-01-01T00:00:00Z")
      n = video("n", nil)
      b = video("b", "2024-02-01T00:00:00Z")

      assert ["b", "a", "n"] == CSV.sort_newest_first([a, n, b]) |> Enum.map(& &1.id)
    end
  end

  describe "merge/2" do
    test "prepends only videos newer than what's already stored, preserving rows" do
      existing = [video("vid1", "2024-02-01T00:00:00Z"), video("vid2", "2024-01-01T00:00:00Z")]

      fetched = [
        video("vid0", "2024-03-01T00:00:00Z", views: 999),
        video("vid1", "2024-02-01T00:00:00Z", views: 12_345),
        video("vid2", "2024-01-01T00:00:00Z", views: 12_345)
      ]

      {merged, added} = CSV.merge(existing, fetched)

      assert added == 1
      assert Enum.map(merged, & &1.id) == ["vid0", "vid1", "vid2"]
      # existing rows are preserved verbatim (not overwritten by the fresh crawl)
      assert Enum.find(merged, &(&1.id == "vid1")).views == 1
    end

    test "is a no-op when nothing is new" do
      existing = [video("vid1", "2024-02-01T00:00:00Z")]
      {merged, added} = CSV.merge(existing, existing)

      assert added == 0
      assert Enum.map(merged, & &1.id) == ["vid1"]
    end

    test "deduplicates new videos by id" do
      dup = video("new", "2024-05-01T00:00:00Z")
      {merged, added} = CSV.merge([], [dup, dup])

      assert added == 1
      assert Enum.map(merged, & &1.id) == ["new"]
    end
  end

  describe "encode/1 and decode/1" do
    test "round-trips, escaping commas/quotes in titles" do
      videos = [
        video("vid0", "2024-03-01T00:00:00Z", title: ~s(Hello, "World")),
        %Video{id: "vid9", title: nil, url: nil, published: nil, views: nil, likes: nil}
      ]

      decoded = videos |> CSV.encode() |> CSV.decode()

      assert Enum.at(decoded, 0).title == ~s(Hello, "World")
      assert Enum.at(decoded, 0).views == 1
      assert Enum.at(decoded, 1) == %Video{id: "vid9"}
    end

    test "encodes the documented header and column order" do
      csv = CSV.encode([video("vid0", "2024-03-01T00:00:00Z")])
      [header | _] = String.split(csv, "\n")
      assert header == "id,title,url,published,views,likes"
    end
  end
end
