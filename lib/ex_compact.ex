defmodule ExCompact do
  @moduledoc """
  Compacts noisy BEAM output (stack traces, test failures, crash reports).
  """

  def compact(text, opts \\ []) do
    ExCompact.Compactor.compact(text, opts)
  end
end
