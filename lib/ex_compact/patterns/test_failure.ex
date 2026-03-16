defmodule ExCompact.Patterns.TestFailure do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  @impl true
  def compact(text, _opts), do: text
end
