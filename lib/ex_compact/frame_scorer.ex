defmodule ExCompact.FrameScorer do
  @moduledoc false

  @otp_apps ~w(stdlib kernel elixir logger compiler crypto ssl inets)

  def score(frame, app_name, position) do
    base =
      cond do
        frame_from_app?(frame, app_name) -> 100
        frame_from_otp?(frame) -> -10
        true -> 10
      end

    base - 5 * position
  end

  def select_top_frames(frames, app_name, opts \\ []) do
    max = Keyword.get(opts, :max_frames, 4)

    frames
    |> Enum.with_index()
    |> Enum.map(fn {frame, idx} -> {frame, score(frame, app_name, idx)} end)
    |> Enum.sort_by(fn {_frame, score} -> -score end)
    |> Enum.take(max)
    |> Enum.sort_by(fn {frame, _score} ->
      Enum.find_index(frames, &(&1 == frame))
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp frame_from_app?(frame, app_name) do
    frame =~ "(#{app_name} "
  end

  defp frame_from_otp?(frame) do
    Enum.any?(@otp_apps, fn otp -> frame =~ "(#{otp} " end)
  end
end
