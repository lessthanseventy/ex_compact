defmodule ExCompact.Patterns.DbDisconnect do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  # Matches Postgrex/DBConnection disconnection reports which are extremely verbose.
  # These contain two full stack traces plus connection metadata.
  # Compact to just the header line.

  @impl true
  def compact(text, _opts) do
    if text =~ "disconnected:" do
      compact_postgrex_disconnects(text)
    else
      text
    end
  end

  defp compact_postgrex_disconnects(text) do
    # Split into lines and process
    lines = String.split(text, "\n")
    {result, _skip} = process_lines(lines, [], false)
    Enum.join(Enum.reverse(result), "\n")
  end

  defp process_lines([], acc, _skip), do: {acc, false}

  defp process_lines([line | rest], acc, false) do
    if line =~ ~r/\[error\] Postgrex\.Protocol.*disconnected:/ do
      # Keep the header, start skipping
      process_lines(rest, [line | acc], true)
    else
      process_lines(rest, [line | acc], false)
    end
  end

  defp process_lines([line | rest], acc, true) do
    cond do
      # Still in the disconnect block — skip indented lines, "Client", "The connection", blank lines
      line == "" ->
        process_lines(rest, acc, true)

      String.starts_with?(line, "    ") ->
        process_lines(rest, acc, true)

      line =~ ~r/^\s*Client #PID/ ->
        process_lines(rest, acc, true)

      line =~ ~r/^\s*The connection itself/ ->
        process_lines(rest, acc, true)

      true ->
        # Hit a non-disconnect line, stop skipping
        process_lines(rest, [line | acc], false)
    end
  end
end
