# Kapten

WIP. Goal is to configure several disparate Elixir apps in one BEAM.

## Usage

Create a new mix project. In this example, we'll call it `:my_ship`.

### Get your deps

Add kapten and the apps you wish to run to your deps.

```elixir
defp kapten_dep(dep \\ []) do
  env = if Mix.env() == :dev, do: :dev, else: :prod

  [ env: env, only: [:dev, :prod] ]
  |> Keyword.merge(dep)
end

def deps do
  [
    {:kapten, "~> 0.1.0"},
    {:my_app, "~> 0.1.0", kapten_dep()},
    {:other_app, "~> 0.1.0", kapten_dep()}
  ]
end
```

### Create config.exs

```elixir
import Config

Mix.Project.deps_paths()
|> Map.get(:kapten)
|> Path.join("config/config.exs")
|> Code.require_file()

defmodule MyShip.Config do
  use Kapten.Config,
    apps: [
      my_app: [env: [dev: [port: 4000]]],
      other_app: [env: [dev: [port: 4001]]]
    ]
end

MyShip.Config.configure_compiletime()

config :kapten, :runtime, MyShip.Config.runtime_configs()
```

### Create runtime.exs

```elixir
import Config

runtime_configs = Application.compile_env!(:kapten, :runtime)

# Warning: we're using an undocumented API here
for {_app, {file, content, opts}} <- runtime_configs,
    do: Config.__eval__!(file, content, opts)

[]
```

## Dependency Requirements

### A dependency must not refer to the `deps` directory with a relative path.

For example, at the time of writing, the Phoenix generator's `:esbuild` config violates this requirement.
The following change should be safe to apply without loss of generality.

```diff
config :esbuild,
  version: "x.y.z",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
-    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
-    env: %{"NODE_PATH" => Mix.Project.deps_path()}
  ]
```

Notice that the `"../assets"` path is ok because that directory is part of the dep project itself, whereas
deps created and managed by `mix` at the top-level only.

### A dependency must allow full configurability of shared system resources

For example, it's common for a dev.config to hard-code a listening port. Since we're starting
several, these can conflict with each other. Our recommended approach is for the dep to optionally
read from the `Mix.Project.config()`. Kapten provides a way to influence this config when it is
compiling its own config.exs.

```diff
config :my_app, MyAppWeb.Endpoint,
# ...
-  http: [ip: {127, 0, 0, 1}, port: 4000],
+  http: [ip: {127, 0, 0, 1}, port: Mix.Project.config()[:env][:dev][:port] || 4000],
```

Your endpoint may not be the only config to consider: any system resource could be a conflict.

## Known Issues

0. Shared dependencies will be challenging to manage. The apps must agree on a common set of deps.
1. The API is awkward. It's challenging to get custom modules loaded into the elixir config files.
2. Upon generating a release, a warning is emitted that `MyShip.Config` is being redefined.
3. Each dep must be sufficiently configurable to avoid conflicts, and the conventional approach to managing dev.exs is incompatible.
4. The rutnime.exs must use an undocumented public API from Config
