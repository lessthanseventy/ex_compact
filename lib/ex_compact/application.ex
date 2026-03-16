defmodule ExCompact.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:ex_compact, :daemon, false) do
        [{ExCompact.Daemon, []}]
      else
        []
      end

    opts = [strategy: :one_for_one, name: ExCompact.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
