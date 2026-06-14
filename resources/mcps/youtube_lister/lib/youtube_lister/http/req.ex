defmodule YoutubeLister.HTTP.Req do
  @moduledoc """
  `Req`-backed implementation of `YoutubeLister.HTTP`, using the supervised
  `YoutubeLister.Finch` pool. Body decoding is disabled here — the InnerTube
  layer decodes JSON itself with the built-in `JSON` module.
  """

  @behaviour YoutubeLister.HTTP

  @impl true
  def get(url, headers) do
    [url: url, headers: headers]
    |> base()
    |> Req.request()
    |> normalize()
  end

  @impl true
  def post(url, headers, body) do
    [url: url, headers: headers, method: :post, body: body]
    |> base()
    |> Req.request()
    |> normalize()
  end

  defp base(opts) do
    Req.new(
      finch: YoutubeLister.Finch,
      decode_body: false,
      retry: :transient,
      max_retries: 2,
      receive_timeout: 30_000
    )
    |> Req.merge(opts)
  end

  defp normalize({:ok, %Req.Response{status: status, body: body}}),
    do: {:ok, %{status: status, body: body}}

  defp normalize({:error, reason}), do: {:error, reason}
end
