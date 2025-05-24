defmodule Mix.Tasks.Kapten.Deploy do
  use Mix.Task

  @impl true
  def run(_args) do
    config = Mix.Project.config()
    deps = config[:deps]

    Enum.each(deps, &run_dep/1)
  end

  defp run_dep({dep_app, dep_config}) do
    deploy_tasks = dep_config[:"kapten.deploy"]
    deps_paths = Mix.Project.deps_paths()

    if deploy_tasks do
      path = deps_paths[dep_app]
      post_config = []

      fun = fn _module ->
        Enum.each(
          deploy_tasks,
          fn deploy_task ->
            [task | args] = OptionParser.split(deploy_task)

            Mix.Task.run(task, args)
          end
        )
      end

      Mix.Project.in_project(dep_app, path, post_config, fun)
    end
  end
end
