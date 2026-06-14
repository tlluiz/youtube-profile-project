defmodule YoutubeLister.InnerTube do
  @moduledoc """
  Thin effectful wrapper over YouTube's anonymous InnerTube surface. All HTTP
  goes through `YoutubeLister.HTTP`; all parsing lives in `YoutubeLister.Parse`.

  Anonymous only: no API key of our own, no OAuth, no login. The `key` query
  param is the public web key scraped from the channel page itself.
  """

  alias YoutubeLister.{HTTP, Parse}

  @base "https://www.youtube.com"
  @youtubei @base <> "/youtubei/v1"

  defmodule Context do
    @moduledoc "Per-run InnerTube client config, scraped from the channel page."
    @enforce_keys [:api_key, :client_version, :user_agent]
    defstruct [:api_key, :client_version, :user_agent]

    @type t :: %__MODULE__{
            api_key: String.t(),
            client_version: String.t(),
            user_agent: String.t()
          }
  end

  @doc """
  Fetches the channel's Videos page and returns the InnerTube `Context` plus the
  first page of video stubs and its continuation token.
  """
  @spec start(String.t(), String.t()) ::
          {:ok, %{context: Context.t(), stubs: [map()], token: String.t() | nil}}
          | {:error, term()}
  def start(channel, user_agent) do
    url = channel_videos_url(channel)

    with {:ok, %{status: 200, body: html}} <- HTTP.get(url, browser_headers(user_agent)),
         {:ok, %{api_key: key, client_version: version}} <- Parse.client_config(html),
         {:ok, data} <- Parse.initial_data(html) do
      context = %Context{api_key: key, client_version: version, user_agent: user_agent}
      {stubs, token} = Parse.videos_from_initial(data)
      {:ok, %{context: context, stubs: stubs, token: token}}
    else
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
      :error -> {:error, :channel_page_unparseable}
    end
  end

  @doc "Fetches one continuation page: `{stubs, next_token}`."
  @spec browse(Context.t(), String.t()) :: {:ok, {[map()], String.t() | nil}} | {:error, term()}
  def browse(context, token) do
    with {:ok, json} <- post(context, "browse", %{"continuation" => token}) do
      {:ok, Parse.videos_from_continuation(json)}
    end
  end

  @doc "Fetches exact view count + ISO publish date + title for a video."
  @spec player(Context.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def player(context, video_id) do
    with {:ok, json} <- post(context, "player", %{"videoId" => video_id}) do
      {:ok, Parse.parse_player(json)}
    end
  end

  @doc "Fetches the like count for a video, or `{:ok, nil}` if not exposed."
  @spec next(Context.t(), String.t()) :: {:ok, integer() | nil} | {:error, term()}
  def next(context, video_id) do
    with {:ok, json} <- post(context, "next", %{"videoId" => video_id}) do
      {:ok, Parse.likes_from_next(json)}
    end
  end

  @doc "Builds the public Videos-tab URL for a handle or channel id."
  @spec channel_videos_url(String.t()) :: String.t()
  def channel_videos_url(channel) do
    channel = String.trim(channel)

    cond do
      String.match?(channel, ~r/^UC[\w-]{22}$/) -> "#{@base}/channel/#{channel}/videos"
      String.starts_with?(channel, "@") -> "#{@base}/#{channel}/videos"
      true -> "#{@base}/@#{channel}/videos"
    end
  end

  # --- internals -----------------------------------------------------------

  defp post(%Context{} = context, endpoint, payload) do
    url = "#{@youtubei}/#{endpoint}?key=#{context.api_key}&prettyPrint=false"
    body = JSON.encode!(Map.merge(%{"context" => request_context(context)}, payload))

    with {:ok, %{status: 200, body: raw}} <- HTTP.post(url, json_headers(context), body),
         {:ok, json} <- Parse.decode_json(raw) do
      {:ok, json}
    else
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      :error -> {:error, :invalid_json}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request_context(%Context{client_version: version}) do
    %{
      "client" => %{"clientName" => "WEB", "clientVersion" => version, "hl" => "en", "gl" => "US"}
    }
  end

  defp browser_headers(user_agent) do
    [{"user-agent", user_agent}, {"accept-language", "en-US,en;q=0.9"}]
  end

  defp json_headers(%Context{} = context) do
    [
      {"content-type", "application/json"},
      {"user-agent", context.user_agent},
      {"accept", "*/*"},
      {"accept-language", "en-US,en;q=0.9"},
      {"origin", @base},
      {"x-youtube-client-name", "1"},
      {"x-youtube-client-version", context.client_version}
    ]
  end
end
