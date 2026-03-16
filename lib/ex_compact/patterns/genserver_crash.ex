defmodule ExCompact.Patterns.GenServerCrash do
  @moduledoc false
  @behaviour ExCompact.Patterns.Pattern

  alias ExCompact.FrameScorer

  @max_state_length 150

  @crash_regex ~r/(\[error\] GenServer \S+ terminating)\n(\*\* \([^\)]+\)[^\n]*)\n((?:[ \t]+\(.*\n)+)(Last message: [^\n]*)\n(State: [^\n]*)/

  @impl true
  def compact(text, opts) do
    app = Keyword.get(opts, :app, :unknown)
    max_frames = Keyword.get(opts, :max_frames, 4)

    Regex.replace(@crash_regex, text, fn _full,
                                         header,
                                         exception,
                                         frames_block,
                                         last_msg,
                                         state ->
      frames = String.split(frames_block, "\n", trim: true)

      project_frames =
        Enum.filter(frames, fn frame -> frame =~ "(#{app} " end)

      basis = if project_frames == [], do: frames, else: project_frames
      selected = FrameScorer.select_top_frames(basis, app, max_frames: max_frames)
      compacted_frames = Enum.join(selected, "\n")
      truncated_state = truncate_state(state)

      "#{header}\n#{exception}\n#{compacted_frames}\n#{last_msg}\n#{truncated_state}"
    end)
  end

  defp truncate_state(state) do
    if String.length(state) > @max_state_length do
      String.slice(state, 0, @max_state_length) <> "... (truncated)"
    else
      state
    end
  end
end
