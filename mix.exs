defmodule PiFlex.MixProject do
  use Mix.Project
  @default_version "0.9"

  def project do
    [
      app: :pi_flex,
      version: version(),
      description: get_commit_time(),
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:ssh, :logger],
      mod: {PiFlex.Application, []}
    ]
  end

  defp releases do
    [
      pi_flex: [
        overlays: ["envs/"]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dotenvy, "~> 1.0.0"},
      {:thousand_island, "~> 1.0"},
      {:httpoison, "~> 2.0"}
    ]
  end

  defp version do
    case get_version() do
      {:ok, string} ->
        @default_version <> "." <> String.trim(string)

      _ ->
        @default_version
    end
  end

  defp get_version do
    case File.read("VERSION") do
      {:error, _} ->
        case System.cmd("git", ["rev-list", "HEAD", "--count", "-C", "."]) do
          {string, 0} ->
            {:ok, string}

          {error, errno} ->
            {:error, "Could not get version. errno: #{inspect(errno)}, error: #{inspect(error)}"}
        end

      ok ->
        ok
    end
  end

  defp get_commit_time do
    case System.cmd("git", ["log", "-1", "--pretty='%cd'"]) do #, "--date='format:%Y-%m-%d %H:%M:%S'"]) do
      {string, 0} ->
        string

      {_error, _errno} ->
        ""
    end
  end
end
