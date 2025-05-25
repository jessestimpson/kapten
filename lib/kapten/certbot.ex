defmodule Kapten.Certbot do
  defp config() do
    Application.get_env(:kapten, __MODULE__, [])
  end

  def certbot() do
    config()[:certbot]
  end

  def work_dir() do
    (config()[:work_dir] || Path.join(:code.priv_dir(:kapten), "certbot/work"))
    |> Path.expand()
  end

  def logs_dir() do
    (config()[:logs_dir] || Path.join(:code.priv_dir(:kapten), "certbot/logs"))
    |> Path.expand()
  end

  def config_dir() do
    (config()[:config_dir] || Path.join(:code.priv_dir(:kapten), "certbot/config"))
    |> Path.expand()
  end

  def run!(cmd, cert_name, domains) do
    domain_args =
      for(domain <- domains, do: ["--domain", "#{domain}"])
      |> List.flatten()

    cmd =
      [certbot() | cmd] ++
        [
          "--cert-name",
          "#{cert_name}"
        ] ++
        domain_args ++
        [
          "--nginx",
          "--non-interactive",
          "--work-dir",
          work_dir(),
          "--logs-dir",
          logs_dir(),
          "--config-dir",
          config_dir(),
          "--agree-tos",
          "--nginx-ctl",
          Kapten.Nginx.nginx(),
          "--nginx-server-root",
          Kapten.Nginx.root()
        ]

    {stdout, _code} = System.cmd(hd(cmd), tl(cmd), [])

    IO.puts(stdout)

    :ok
  end
end
