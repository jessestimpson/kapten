# Kapten

WIP. Goal is to configure several disparate Elixir apps in one BEAM.

## Dependencies

* openssl
* nginx
* certbot
* certbot-nginx

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

config :kapten, Kapten.OpenSSL, openssl: "/usr/bin/openssl"

config :kapten, Kapten.Certbot,
  certbot: "/opt/homebrew/bin/certbot",
  email: "your-email@example.com"

config :kapten, Kapten.Nginx, nginx: "/opt/homebrew/opt/nginx/bin/nginx"

if config_env() == :prod do
  config :kapten, Kapten.Nginx,
    tls_servers: ["myapp.example.com": [http: 4000], "otherapp.example.com": [http: 4001]]
end

kapten_config =
  Mix.Project.deps_paths()
  |> Map.get(:kapten)
  |> Path.join("config/config.exs")

if File.exists?(kapten_config) do
  Code.require_file(kapten_config)

  defmodule MyShip.Config do
    use Kapten.Config,
      apps: [
        my_app: [env: [dev: [port: 4000]]],
        other_app: [env: [dev: [port: 4001]]]
      ]
  end

  MyShip.Config.configure_compiletime()
end

[]
```

### Create runtime.exs

```elixir
import Config

if config_env() == :prod do
  System.put_env("PHX_HOST", "myapp.example.com")
end

MyShip.Config.configure_runtime([:my_app])

if config_env() == :prod do
  System.put_env("PHX_HOST", "otherapp.example.com")
end

MyShip.Config.configure_runtime([:other_app])
```

### Running mix tasks for deploy preparation

In your Mix Project's deps, add a `:"kapten.deploy"` key that specifies any mix tasks to run before deployment.

```elixir
# mix.exs
# ...
  defp deps do
    [
      {:kapten, github: "jessestimpson/kapten"},
      {:my_app, kapten_dep(github: "jessestimpson/my_app", "kapten.deploy": ["phx.digest --no-compile"])},
      {:stimpson, kapten_dep(github: "jessestimpson/other_app", "kapten.deploy": ["phx.digest --no-compile"])}
    ]
  end
# ...
```

```bash
MIX_ENV=prod mix kapten.deploy
```

### Starting the VM

```bash
MIX_ENV=prod elixir -S mix kapten.start
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
+    env: %{"NODE_PATH" => Mix.Project.deps_path()}
  ]
```

Notice that the `"../assets"` path is ok because that directory is part of the dep project itself, whereas
deps created and managed by `mix` at the top-level only.

@todo: newish geneator adds a reference to deps dir in tailwind.config.js, which is a problem

### A dependency must allow full configurability of shared system resources

For example, it's common for a config/dev.exs to hard-code a listening port. Since we're starting
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
2. Releases are not supported
3. Each dep must be sufficiently configurable to avoid conflicts, and the conventional approach to managing dev.exs is incompatible.
4. Kapten uses undocumented public API from Elixir Config
5. Elixir LSP will complain about using Kapten.Config in the confix.exs because it doesn't know it's being required from the Kapten config.exs.
