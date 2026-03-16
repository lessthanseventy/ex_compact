defmodule ExCompact.Patterns.TestSummary do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  @impl true
  def compact(text, _opts) do
    if text =~ ~r/\d+ tests?, \d+ failures?/ and text =~ ~r/^[\.F]{10,}/m do
      text
      |> remove_running_line()
      |> remove_test_dots()
      |> remove_seed_line()
      |> remove_finished_line()
      |> collapse_blank_lines()
      |> String.trim()
      |> Kernel.<>("\n")
    else
      text
    end
  end

  defp remove_running_line(text) do
    Regex.replace(~r/^Running ExUnit with seed.*\n*/m, text, "")
  end

  defp remove_test_dots(text) do
    Regex.replace(~r/^[\.F]+\n*/m, text, "")
  end

  defp remove_seed_line(text) do
    Regex.replace(~r/^\n*Randomized with seed \d+\n*/m, text, "")
  end

  defp remove_finished_line(text) do
    Regex.replace(~r/^Finished in .*\n/m, text, "")
  end

  defp collapse_blank_lines(text) do
    Regex.replace(~r/\n{3,}/, text, "\n\n")
  end
end
