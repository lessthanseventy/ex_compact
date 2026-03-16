defmodule ExCompact.Patterns.CompilerWarning do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  @impl true
  def compact(text, _opts) do
    if text =~ ~r/^warning: /m do
      extract_and_compact_warnings(text)
    else
      text
    end
  end

  defp extract_and_compact_warnings(text) do
    text
    |> compact_boxdraw_warnings()
    |> compact_simple_warnings()
    |> remove_compilation_line()
    |> collapse_blank_lines()
    |> String.trim()
    |> Kernel.<>("\n")
  end

  # Box-drawing style: warning + │ lines + └─ location
  defp compact_boxdraw_warnings(text) do
    Regex.replace(
      ~r/^(warning: [^\n]+)\n(?:[│└─\s].*\n)*└─\s*([^\n]+)/m,
      text,
      fn _, msg, location ->
        "warning: #{clean_message(msg)} — #{String.trim(location)}"
      end
    )
  end

  # Simple style: warning message\n  location:line:col
  defp compact_simple_warnings(text) do
    Regex.replace(
      ~r/^(warning: [^\n]+?)(?:\s*\([^)]+\))?\n\s+([\w\/][^\n]*:\d+:\d+)/m,
      text,
      fn _, msg, location ->
        "#{clean_message(msg)} — #{String.trim(location)}"
      end
    )
  end

  defp clean_message("warning: " <> rest), do: "warning: " <> clean_msg_text(rest)
  defp clean_message(msg), do: clean_msg_text(msg)

  defp clean_msg_text(msg) do
    # Strip trailing parenthetical suggestions like "(if the variable is not meant to...)"
    Regex.replace(~r/\s*\([^)]{20,}\)\s*$/, msg, "")
  end

  defp remove_compilation_line(text) do
    Regex.replace(~r/^Compiling \d+ files? \(\.ex\)\n*/m, text, "")
  end

  defp collapse_blank_lines(text) do
    Regex.replace(~r/\n{3,}/, text, "\n")
  end
end
