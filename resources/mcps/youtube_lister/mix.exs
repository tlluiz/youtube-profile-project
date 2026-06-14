defmodule YoutubeLister.MixProject do
  use Mix.Project

  def project do
    [
      app: :youtube_lister,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets],
      mod: {YoutubeLister.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # MCP server framework (stdio transport). https://hexdocs.pm/hermes_mcp/
      # Pinned to the 0.11.x line: 0.12.0 regressed the stdio transport — its
      # `process_message/2` stopped unwrapping the decoded message list and
      # raises BadMapError on every request (verified against 0.14.1 source).
      # 0.11.3 exposes the same server/component/Response API used here.
      {:hermes_mcp, "~> 0.11.3"},
      # HTTP client per the Skill, backed by Finch/Mint with HTTP/2. https://hexdocs.pm/req/
      {:req, "~> 0.6"},
      # Supervised Finch pool so outbound HTTP lives under the tree.
      {:finch, "~> 0.22"},
      # De-facto CSV library for robust RFC-4180 encode/decode. https://hexdocs.pm/nimble_csv/
      {:nimble_csv, "~> 1.0"},
      # Behaviour mocking at the HTTP boundary in tests. https://hexdocs.pm/mox/
      {:mox, "~> 1.2", only: :test}
    ]
  end
end
