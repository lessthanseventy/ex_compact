defmodule ExCompact.Patterns.StackTrace do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  alias ExCompact.FrameScorer

  # Match ** (ExceptionType) message followed by indented stack frames
  @trace_regex ~r/(\*\* \([^\)]+\)[^\n]*)\n((?:[ \t]+\(.*\n?)+)/

  @impl true
  def compact(text, opts) do
    app = Keyword.get(opts, :app) |> detect_app()
    max_frames = Keyword.get(opts, :max_frames, 4)

    Regex.replace(@trace_regex, text, fn _full, exception_line, frames_block ->
      frames = String.split(frames_block, "\n", trim: true)

      selected =
        frames
        |> Enum.with_index()
        |> Enum.map(fn {frame, idx} -> {frame, FrameScorer.score(frame, app, idx)} end)
        |> Enum.filter(fn {_frame, score} -> score > 0 end)
        |> Enum.sort_by(fn {_frame, score} -> -score end)
        |> Enum.take(max_frames)
        |> Enum.sort_by(fn {frame, _score} ->
          Enum.find_index(frames, &(&1 == frame))
        end)
        |> Enum.map(&elem(&1, 0))

      compacted_frames = Enum.join(selected, "\n")
      "#{exception_line}\n#{compacted_frames}\n"
    end)
  end

  defp detect_app(nil) do
    Mix.Project.config()[:app]
  rescue
    _ -> :unknown
  end

  defp detect_app(app), do: app
end
