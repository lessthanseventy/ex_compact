defmodule ExCompact.Compactor do
  @moduledoc false

  @patterns [
    ExCompact.Patterns.StackTrace,
    ExCompact.Patterns.TestFailure,
    ExCompact.Patterns.GenServerCrash,
    ExCompact.Patterns.ProcessCrash,
    ExCompact.Patterns.TestSummary,
    ExCompact.Patterns.CompilerWarning
  ]

  def compact(text, opts \\ []) do
    Enum.reduce(@patterns, text, fn pattern, acc ->
      try do
        pattern.compact(acc, opts)
      rescue
        _ -> acc
      end
    end)
  end
end
