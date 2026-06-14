# Ad-hoc end-to-end driver: mix run --no-start priv/e2e.exs <channel> <max_pages> <videos_dir>
Application.put_env(:youtube_lister, :start_server?, false)
{:ok, _} = Application.ensure_all_started(:youtube_lister)

[channel, max_pages, dir] = System.argv()

{:ok, summary} =
  YoutubeLister.run(channel,
    videos_dir: dir,
    max_pages: String.to_integer(max_pages),
    max_concurrency: 5
  )

IO.inspect(summary, label: "summary")
