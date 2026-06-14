defmodule YoutubeLister.YoutubeFixtures do
  @moduledoc """
  Builds InnerTube-shaped fixture bodies for tests, mirroring the structures
  verified against live YouTube responses. JSON is built from Elixir maps with
  the built-in `JSON` module so the shapes stay readable.
  """

  # id => {title, views, likes, publishDate}
  @catalog %{
    "vid0" => %{title: "Newest", views: 300, likes: 30, date: "2024-03-01T00:00:00Z"},
    "vid1" => %{title: "Middle", views: 200, likes: 20, date: "2024-02-01T00:00:00Z"},
    "vid2" => %{title: "Oldest", views: 100, likes: 10, date: "2024-01-01T00:00:00Z"}
  }

  def catalog, do: @catalog

  @doc "Channel `/videos` page HTML embedding ytInitialData + client config."
  def channel_html(ids, token \\ nil) do
    data = %{
      "contents" => %{
        "twoColumnBrowseResultsRenderer" => %{
          "tabs" => [
            %{
              "tabRenderer" => %{
                "selected" => true,
                "content" => %{"richGridRenderer" => %{"contents" => grid_items(ids, token)}}
              }
            }
          ]
        }
      }
    }

    """
    <html><body>
    <script>var ytInitialData = #{JSON.encode!(data)};</script>
    <script>ytcfg.set({"INNERTUBE_API_KEY":"KEY123","INNERTUBE_CONTEXT_CLIENT_VERSION":"2.20260612.01.00"});</script>
    </body></html>
    """
  end

  @doc "A `browse` continuation response with the given video ids and no further token."
  def browse_json(ids) do
    JSON.encode!(%{
      "onResponseReceivedActions" => [
        %{
          "appendContinuationItemsAction" => %{
            "continuationItems" => Enum.map(ids, &video_item/1)
          }
        }
      ]
    })
  end

  @doc "A `player` response for a known id; empty for an unknown id."
  def player_json(id) do
    case @catalog do
      %{^id => %{title: title, views: views, date: date}} ->
        JSON.encode!(%{
          "videoDetails" => %{"title" => title, "viewCount" => Integer.to_string(views)},
          "microformat" => %{"playerMicroformatRenderer" => %{"publishDate" => date}}
        })

      _ ->
        JSON.encode!(%{})
    end
  end

  @doc "A `next` response carrying the like count in the like-button accessibility text."
  def next_json(id) do
    case @catalog do
      %{^id => %{likes: likes}} ->
        JSON.encode!(%{
          "engagementPanels" => %{
            "likeButton" => %{
              "accessibilityText" => "like this video along with #{likes} other people"
            }
          }
        })

      _ ->
        JSON.encode!(%{})
    end
  end

  defp grid_items(ids, nil), do: Enum.map(ids, &video_item/1)
  defp grid_items(ids, token), do: Enum.map(ids, &video_item/1) ++ [continuation_item(token)]

  defp video_item(id) do
    title = get_in(@catalog, [id, :title]) || id

    %{
      "richItemRenderer" => %{
        "content" => %{
          "lockupViewModel" => %{
            "contentId" => id,
            "contentType" => "LOCKUP_CONTENT_TYPE_VIDEO",
            "metadata" => %{"lockupMetadataViewModel" => %{"title" => %{"content" => title}}}
          }
        }
      }
    }
  end

  defp continuation_item(token) do
    %{
      "continuationItemRenderer" => %{
        "continuationEndpoint" => %{"continuationCommand" => %{"token" => token}}
      }
    }
  end
end
