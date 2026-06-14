defmodule YoutubeLister.HTTP do
  @moduledoc """
  The HTTP boundary. All outbound requests go through this behaviour so the rest
  of the system stays pure and tests can mock it (see `YoutubeLister.HTTPMock`).

  Implementations return `{:ok, %{status: integer, body: binary}}` on a completed
  exchange (any status — callers decide what a non-200 means) or `{:error, term}`
  when the request could not be completed at all.
  """

  @type response :: %{status: non_neg_integer(), body: binary()}
  @type headers :: [{String.t(), String.t()}]

  @callback get(url :: String.t(), headers()) :: {:ok, response()} | {:error, term()}
  @callback post(url :: String.t(), headers(), body :: iodata()) ::
              {:ok, response()} | {:error, term()}

  @doc "The configured HTTP client implementation."
  @spec impl() :: module()
  def impl, do: Application.get_env(:youtube_lister, :http_client, YoutubeLister.HTTP.Req)

  @spec get(String.t(), headers()) :: {:ok, response()} | {:error, term()}
  def get(url, headers \\ []), do: impl().get(url, headers)

  @spec post(String.t(), headers(), iodata()) :: {:ok, response()} | {:error, term()}
  def post(url, headers, body), do: impl().post(url, headers, body)
end
