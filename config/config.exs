require Config
require Logger

defmodule Kapten.Config do
  require Logger

  defmacro __using__(opts) do
    quote do
      @apps unquote(opts[:apps])
      @runtime_configs Kapten.Config.__build_runtime_configs__(unquote(Keyword.keys(opts[:apps])))

      def configure_compiletime(app_names \\ unquote(opts[:apps] |> Keyword.keys())) do
        apps = Keyword.take(@apps, app_names)
        Kapten.Config.__configure_compiletime__(apps)
      end

      def runtime_configs(), do: @runtime_configs
    end
  end

  def __configure_compiletime__(post_configs) do
    deps_paths = Mix.Project.deps_paths()

    for {app, pc} <- post_configs do
      Map.has_key?(deps_paths, app) || raise "Project #{inspect(app)} not found"

      file = Path.join(deps_paths[app], "config/config.exs")

      if File.exists?(file) do
        Mix.Project.in_project(
          app,
          deps_paths[app],
          pc,
          fn _module ->
            Config.import_config(Path.join(deps_paths[app], "config/config.exs"))
          end
        )
      else
        Logger.info("#{app}/config/config.exs not found")
      end
    end

    []
  end

  def __build_runtime_configs__(apps) do
    build_runtime_configs(apps, [])
  end

  defp build_runtime_configs([], acc), do: Enum.reverse(acc)

  defp build_runtime_configs([app | apps], acc) do
    deps_paths = Mix.Project.deps_paths()
    Map.has_key?(deps_paths, app) || raise "Project #{inspect(app)} not found"

    file = Path.join(deps_paths[app], "config/runtime.exs")
    opts = [env: Mix.env(), target: Mix.target(), imports: :disabled]

    if File.exists?(file) do
      build_runtime_configs(apps, [{app, {file, File.read!(file), opts}} | acc])
    else
      Logger.info("#{app}/config/runtime.exs not found")
      build_runtime_configs(apps, acc)
    end
  end
end
