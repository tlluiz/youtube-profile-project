defmodule YoutubeLister.ListerTest do
  # async: false — Mox runs in global mode so the crawl's Task processes can
  # reach the mock (HTTP is mocked at the YoutubeLister.HTTP boundary).
  use ExUnit.Case, async: false

  import Mox

  alias YoutubeLister.{CSV, Lister}
  alias YoutubeLister.YoutubeFixtures, as: Fix

  setup :set_mox_global

  setup do
    dir = Path.join(System.tmp_dir!(), "yt_lister_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(dir) end)
    %{dir: dir}
  end

  # Installs an HTTP stub: channel page lists `initial_ids` + a continuation
  # token, the single browse page returns `cont_ids`. `fail_next` makes the
  # `next` (likes) request error for those ids.
  defp stub_http(initial_ids, cont_ids, fail_next \\ []) do
    stub(YoutubeLister.HTTPMock, :get, fn url, _headers ->
      if String.contains?(url, "/videos"),
        do: {:ok, %{status: 200, body: Fix.channel_html(initial_ids, "TOKEN1")}},
        else: {:ok, %{status: 404, body: ""}}
    end)

    stub(YoutubeLister.HTTPMock, :post, fn url, _headers, body ->
      {:ok, decoded} = JSON.decode(body)
      id = decoded["videoId"]

      cond do
        String.contains?(url, "/browse") -> {:ok, %{status: 200, body: Fix.browse_json(cont_ids)}}
        String.contains?(url, "/player") -> {:ok, %{status: 200, body: Fix.player_json(id)}}
        String.contains?(url, "/next") and id in fail_next -> {:error, :boom}
        String.contains?(url, "/next") -> {:ok, %{status: 200, body: Fix.next_json(id)}}
      end
    end)
  end

  test "writes a newest-first CSV with all columns", %{dir: dir} do
    stub_http(["vid1"], ["vid2"])

    assert {:ok, summary} = Lister.run("@example", videos_dir: dir)
    assert summary.total_stored == 2
    assert summary.newly_prepended == 2
    assert summary.path == Path.join([dir, "example", "list.csv"])

    rows = dir |> Path.join("example/list.csv") |> File.read!() |> CSV.decode()
    assert Enum.map(rows, & &1.id) == ["vid1", "vid2"]

    first = hd(rows)
    assert first.title == "Middle"
    assert first.url == "https://www.youtube.com/watch?v=vid1"
    assert first.published == "2024-02-01T00:00:00Z"
    assert first.views == 200
    assert first.likes == 20
  end

  test "tolerates per-video metric failures, still storing the video", %{dir: dir} do
    stub_http(["vid1"], ["vid2"], _fail_next = ["vid2"])

    assert {:ok, summary} = Lister.run("@example", videos_dir: dir)
    assert summary.total_stored == 2

    rows = dir |> Path.join("example/list.csv") |> File.read!() |> CSV.decode()
    vid2 = Enum.find(rows, &(&1.id == "vid2"))
    assert vid2.views == 100
    assert vid2.likes == nil
  end

  test "re-runs prepend only new videos and keep existing rows", %{dir: dir} do
    stub_http(["vid1"], ["vid2"])
    assert {:ok, %{total_stored: 2, newly_prepended: 2}} = Lister.run("@example", videos_dir: dir)

    # Second run: a newer video (vid0) has appeared at the top of the channel.
    stub_http(["vid0", "vid1"], ["vid2"])
    assert {:ok, summary} = Lister.run("@example", videos_dir: dir)

    assert summary.newly_prepended == 1
    assert summary.total_stored == 3

    rows = dir |> Path.join("example/list.csv") |> File.read!() |> CSV.decode()
    assert Enum.map(rows, & &1.id) == ["vid0", "vid1", "vid2"]
  end

  test "returns an error when the channel page cannot be fetched", %{dir: dir} do
    stub(YoutubeLister.HTTPMock, :get, fn _url, _headers -> {:ok, %{status: 404, body: ""}} end)
    assert {:error, {:http_status, 404}} = Lister.run("@missing", videos_dir: dir)
  end
end
