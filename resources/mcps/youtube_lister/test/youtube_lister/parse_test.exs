defmodule YoutubeLister.ParseTest do
  use ExUnit.Case, async: true

  alias YoutubeLister.Parse
  alias YoutubeLister.YoutubeFixtures, as: Fix

  describe "client_config/1" do
    test "extracts api key and client version from channel HTML" do
      html = Fix.channel_html(["vid1"], "TOKEN")

      assert {:ok, %{api_key: "KEY123", client_version: "2.20260612.01.00"}} =
               Parse.client_config(html)
    end

    test "returns :error when absent" do
      assert :error == Parse.client_config("<html></html>")
    end
  end

  describe "initial_data + videos_from_initial" do
    test "extracts video stubs and the continuation token" do
      html = Fix.channel_html(["vid1", "vid2"], "TOKEN1")
      {:ok, data} = Parse.initial_data(html)
      {stubs, token} = Parse.videos_from_initial(data)

      assert Enum.map(stubs, & &1.id) == ["vid1", "vid2"]
      assert Enum.at(stubs, 0).title == "Middle"
      assert token == "TOKEN1"
    end

    test "token is nil on the last page" do
      html = Fix.channel_html(["vid1"], nil)
      {:ok, data} = Parse.initial_data(html)
      assert {[%{id: "vid1"}], nil} = Parse.videos_from_initial(data)
    end
  end

  describe "videos_from_continuation/1" do
    test "extracts appended items and a nil token when exhausted" do
      {:ok, data} = Parse.decode_json(Fix.browse_json(["vid2"]))
      assert {[%{id: "vid2"}], nil} = Parse.videos_from_continuation(data)
    end
  end

  describe "parse_player/1" do
    test "extracts exact views and ISO publish date" do
      {:ok, json} = Parse.decode_json(Fix.player_json("vid1"))

      assert %{views: 200, published: "2024-02-01T00:00:00Z", title: "Middle"} =
               Parse.parse_player(json)
    end

    test "yields nils for an empty response" do
      {:ok, json} = Parse.decode_json(Fix.player_json("unknown"))
      assert %{views: nil, published: nil, title: nil} = Parse.parse_player(json)
    end
  end

  describe "likes_from_next/1" do
    test "extracts the like count from the accessibility text" do
      {:ok, json} = Parse.decode_json(Fix.next_json("vid1"))
      assert Parse.likes_from_next(json) == 20
    end

    test "returns nil when no like text is present" do
      {:ok, json} = Parse.decode_json(Fix.next_json("unknown"))
      assert Parse.likes_from_next(json) == nil
    end
  end

  describe "parse_int/1" do
    test "strips separators from exact counts" do
      assert Parse.parse_int("432,023") == 432_023
      assert Parse.parse_int("15546630") == 15_546_630
      assert Parse.parse_int(nil) == nil
      assert Parse.parse_int("n/a") == nil
    end
  end

  describe "extract_json_object/2" do
    test "balances braces across nested objects and string literals" do
      html = ~s(prefix ytInitialData = {"a":{"b":"has } brace"},"c":1}; suffix)
      assert {:ok, json} = Parse.extract_json_object(html, "ytInitialData = ")
      assert {:ok, %{"a" => %{"b" => "has } brace"}, "c" => 1}} = Parse.decode_json(json)
    end
  end
end
