require Logger
require Config

defmodule Kapten.Config do
  require Logger

  defmacro __using__(opts) do
    quote do
      @apps unquote(opts[:apps])
      @runtime_configs Kapten.Config.__build_runtime_configs__(unquote(Keyword.keys(opts[:apps])))
      @runtime_config_process_key :kapten_runtime_config

      def configure_compiletime(app_names \\ unquote(opts[:apps] |> Keyword.keys())) do
        apps = Keyword.take(@apps, app_names)
        Kapten.Config.__configure_compiletime__(apps)
      end

      def configure_runtime(app_names \\ unquote(opts[:apps] |> Keyword.keys())) do
        runtime_configs = Keyword.take(@runtime_configs, app_names)

        # Warning: we're using an undocumented API here
        new_config =
          Enum.reduce(runtime_configs, [], fn {app, {file, content, opts}}, acc ->
            {app_config, _} = Config.__eval__!(file, content, opts)
            Config.__merge__(acc, app_config)
          end)

        # Merging with config from process dictionary ensures final call in runtime.exs returns all configs
        proc_config = Process.get(@runtime_config_process_key, [])
        proc_config = Config.__merge__(proc_config, new_config)
        Process.put(@runtime_config_process_key, proc_config)
        proc_config
      end

      def runtime_configs(), do: @runtime_configs
    end
  end

  def __configure_compiletime__(post_configs) do
    deps_paths = Mix.Project.deps_paths()

    top_level_deps_path = Mix.Project.deps_path()

    for {app, pc} <- post_configs do
      Map.has_key?(deps_paths, app) || raise "Project #{inspect(app)} not found"

      file = Path.join(deps_paths[app], "config/config.exs")

      if File.exists?(file) do
        # Must override deps path
        post_config = Keyword.merge(pc, deps_path: top_level_deps_path)

        Mix.Project.in_project(
          app,
          deps_paths[app],
          post_config,
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
