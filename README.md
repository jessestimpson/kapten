# Kapten

Kapten is a tool for hosting multiple disparate Elixir apps in one BEAM.

* Supports any Elixir app
* TLS connections
* Static apps

Kapten is highly opinionated, and was built for my own personal use.

## Motivation

I was tired of running containers.

## Dependencies

* openssl
* nginx
* certbot
* certbot-nginx

### Disable services

Kapten manages services using a supervisor. We do not want systemd to interfere,
so after you install the dependencies, make sure they're all stopped and disabled.

```
systemctl stop nginx && systemctl mask nginx
systemctl stop certbot.timer && systemctl mask certbot.timer
systemctl stop certbot && systemctl mask certbot
```

## Usage

Create a new mix project. In this example, we'll call it `:my_ship`. This project will
contain all the set-up configuration for the apps you want to host. Think of it as the
replacement for compose.yaml. Instead of configuring a compose file, the entire Elixir
`:my_ship` project holds our configuration.

### Mix envs

We recommend that `:my_ship` only supports the `:prod` Mix env. Add the following to
a `.env` file. Later, we'll use this file to configure application secrets. Don't check
it in.

```
# .env
export MIX_ENV=prod
```

```
echo .env >> .gitignore
```

### Get your deps

Add kapten and the apps you wish to run to your deps.

```elixir
def deps do
  [
    {:kapten, "~> 0.1.0"},
    {:my_app, "~> 0.1.0"},
    {:other_app, "~> 0.1.0"}
  ]
end
```

### Create config.exs

```elixir
import Config

# System configuration for the openssl binary path
config :kapten, Kapten.OpenSSL, openssl: "/usr/bin/openssl"

# System configuration for the certbot binary path, and your email address to register with Let's Encrypt
config :kapten, Kapten.Certbot,
  certbot: "/opt/homebrew/bin/certbot",
  email: "your-email@example.com"

# System configuration for the nginx binary path
config :kapten, Kapten.Nginx, nginx: "/opt/homebrew/opt/nginx/bin/nginx"

# Defines the TLS servers for your Ship. `http` will be a reverse proxy, `static` will simply be an
# nginx `root` directory. You can't mix them.
if config_env() == :prod do
  config :kapten, Kapten.Nginx,
    tls_servers: [
      "myapp.example.com": [http: 4000],
      "otherapp.example.com": [http: 4001],
      "docs.example.com": [static: "path/to/static/relative/to/my_ship/priv"]
    ]
end

# We need to lead the Kapten.Config module from kapten's dep location, and then require it.
kapten_config =
  Mix.Project.deps_paths()
  |> Map.get(:kapten)
  |> Path.join("config/config.exs")

if File.exists?(kapten_config) do
  Code.require_file(kapten_config)
else
  raise "kapten config file not found"
end

# Configure Kapten.Config to be aware of our apps
defmodule MyShip.Config do
  use Kapten.Config,
    otp_app: :my_ship,
    apps: [
      my_app: [env: [dev: [port: 4000]]],
      other_app: [env: [dev: [port: 4001]]]
    ]
end

# Now we import each app's config.exs
MyShip.Config.configure_compiletime()

[]
```

### Create runtime.exs

```elixir
import Config

# Each app will have runtime config that expects various env vars. We set those
# vars and then configure the app's runtime config.

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
      {:my_app, github: "jessestimpson/my_app", "kapten.deploy": ["phx.digest --no-compile"]},
      {:other_app, github: "jessestimpson/other_app", "kapten.deploy": ["phx.digest --no-compile"]}
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

## System setup

### start script

The `.env` file sets up all the env vars required by your config. These can be secrets. Don't check them in.

```
# .env
export MIX_ENV=prod
export MYAPP_SECRET_KEY_BASE="foobar"
export OTHERAPP_SECRET_KEY_BASE="bazbuz"
```

The `start.sh` script starts the app. It can be a helpful thing to add if you're using asdf.

```
# start.sh
#!/bin/bash
export ASDF_DATA_DIR=/home/kapten/.asdf
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
source .env
mix kapten.start
```

### systemd

The `my_ship.service` file tells systemd how to start the app. The `CAP_NET_BIND_SERVICE` capability is required to bind to ports below 1024.

```
# my_ship.service
[Unit]
Description=My Ship Service
After=network.target

[Service]
User=kapten
Group=kapten
WorkingDirectory=/home/kapten/my_ship
ExecStart=/home/kapten/my_ship/start.sh
Restart=on-failure
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
```

Disable all services that Kapten and MyShip manage:

```
# Required
systemctl stop nginx && systemctl mask nginx
systemctl stop certbot.timer && systemctl mask certbot.timer
systemctl stop certbot && systemctl mask certbot

# App-specific example
systemctl stop foundationdb && systemctl mask foundationdb
```

### apt unattended-upgrades

If you're using unattended-upgrades, you may want to add your service to the Blacklist. Doing so will
prevent it from being restarted by the system. Here's how to do it:

```
vim /etc/apt/apt.conf.d/50unattended-upgrades
```

```
// List of services to not restart automatically
Unattended-Upgrade::Services-Blacklist {
    // "ssh";
    "my_ship.service";
};
```

## Known Issues

0. Shared dependencies will be challenging to manage. The apps must agree on a common set of deps.
1. The API is awkward. It's challenging to get custom modules loaded into the elixir config files.
2. Releases are not supported
3. Each dep must be sufficiently configurable to avoid conflicts, and the conventional approach to managing dev.exs is incompatible.
4. Kapten uses undocumented public API from Elixir Config
5. Elixir LSP will complain about using Kapten.Config in the confix.exs because it doesn't know it's being required from the Kapten config.exs.
