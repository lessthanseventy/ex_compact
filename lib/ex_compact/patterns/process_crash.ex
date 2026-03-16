defmodule ExCompact.Patterns.ProcessCrash do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  alias ExCompact.FrameScorer

  @task_regex ~r/(\[error\] Task #PID<[^>]+> started from \S+ terminating)\n(\*\* \([^\)]+\)[^\n]*)\n((?:[ \t]+\(.*\n)+)(?:Function: [^\n]*\n(?:[ \t]+Args: [^\n]*\n?)?)?/

  @supervisor_regex ~r/(\[error\] Child \S+ of Supervisor \S+ terminated)\n(\*\* \(exit\) an exception was raised:\n[ \t]+\*\* \([^\)]+\)[^\n]*)\n((?:[ \t]+\(.*\n)+)(?:Pid: [^\n]*\n)?(?:Start Call: [^\n]*\n?)?/

  @impl true
  def compact(text, opts) do
    app = Keyword.get(opts, :app, :unknown)
    max_frames = Keyword.get(opts, :max_frames, 4)

    text
    |> compact_task_crashes(app, max_frames)
    |> compact_supervisor_crashes(app, max_frames)
  end

  defp compact_task_crashes(text, app, max_frames) do
    Regex.replace(@task_regex, text, fn _full, header, exception, frames_block ->
      compact_block(header, exception, frames_block, app, max_frames)
    end)
  end

  defp compact_supervisor_crashes(text, app, max_frames) do
    Regex.replace(@supervisor_regex, text, fn _full, header, exception, frames_block ->
      compact_block(header, exception, frames_block, app, max_frames)
    end)
  end

  defp compact_block(header, exception, frames_block, app, max_frames) do
    frames = String.split(frames_block, "\n", trim: true)

    project_frames =
      Enum.filter(frames, fn frame -> frame =~ "(#{app} " end)

    basis = if project_frames == [], do: frames, else: project_frames
    selected = FrameScorer.select_top_frames(basis, app, max_frames: max_frames)
    compacted_frames = Enum.join(selected, "\n")

    "#{header}\n#{exception}\n#{compacted_frames}"
  end
end
