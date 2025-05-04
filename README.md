# Kapten

**TODO: Add description**

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

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `kapten` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kapten, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/kapten>.
