defmodule ExCompact.Patterns.EctoLog do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  @impl true
  def compact(text, _opts) do
    if text =~ "[debug] QUERY" do
      text
      |> strip_ok_queries()
      |> collapse_blank_lines()
      |> String.trim()
      |> Kernel.<>("\n")
    else
      text
    end
  end

  # Strip [debug] QUERY OK line + the following SQL line
  defp strip_ok_queries(text) do
    Regex.replace(
      ~r/^\[debug\] QUERY OK[^\n]*\n[^\n]*\n?/m,
      text,
      ""
    )
  end

  defp collapse_blank_lines(text) do
    Regex.replace(~r/\n{3,}/, text, "\n\n")
  end
end
