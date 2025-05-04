defmodule Mix.Tasks.Kapten.Start do
  # Initially copied from phx.server.ex
  use Mix.Task

  @impl true
  def run(args) do
    Application.put_env(:phoenix, :serve_endpoints, true, persistent: true)
    Mix.Tasks.Run.run(open_args(args) ++ run_args())
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end

  defp open_args(args) do
    if "--open" in args do
      Application.put_env(:phoenix, :browser_open, true)
      args -- ["--open"]
    else
      args
    end
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end
end
