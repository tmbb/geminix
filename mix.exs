defmodule Geminix.MixProject do
  use Mix.Project

  def project do
    [
      app: :geminix,
      version: "0.1.0",
      elixir: "~> 1.19",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: &docs/0,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: [
        "geminix.docs": [
          &create_group_for_modules_file/1,
          "docs"
        ]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib/", "test/fixtures/"]
  defp elixirc_paths(_other), do: ["lib/"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Geminix.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:progress_bar, "~> 3.0"},
      {:ecto, "~> 3.13"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:req_cassette, "~> 0.5"},
      {:expublish, "~> 2.7", only: :dev, runtime: false},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Elixir bindings to the Google Gemini API."
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs meta mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/tmbb/geminix"}
    ]
  end

  defp docs() do
    [
      groups_for_modules: groups_for_modules()
    ]
  end

  defp groups_for_modules() do
    groups =
      "meta/groups_for_modules.json"
      |> File.read!()
      |> Jason.decode!()

    meta_groups =
      for group <- groups do
        name = String.to_atom(group["name"])
        module_strings = group["modules"]

        modules = Enum.map(module_strings, fn s -> Module.concat([s]) end)

        {name, modules}
      end

    meta_groups
  end

  def create_group_for_modules_file(_args) do
    # Make the app functions available
    Mix.Task.run("app.start")

    Geminix.Meta.create_json_group_for_modules_file(
      "vendor/v1beta_api.json",
      "meta/groups_for_modules.json"
    )
  end
end
