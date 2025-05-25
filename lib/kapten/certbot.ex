defmodule Kapten.Certbot do
  defp config() do
    Application.get_env(:kapten, __MODULE__, [])
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

    globals = %{
      "cli_args" =>
        cmd ++
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
            Kapten.Nginx.ctl(),
            "--nginx-server-root",
            Kapten.Nginx.root()
          ]
    }

    python = """
    from certbot import main
    cli_args = [ x.decode(encoding="utf-8") for x in cli_args]
    main.main(cli_args)
    """

    Pythonx.eval(python, globals)
    :ok
  end
end
