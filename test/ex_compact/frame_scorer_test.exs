defmodule ExCompact.FrameScorerTest do
  use ExUnit.Case, async: true

  alias ExCompact.FrameScorer

  @app_name :my_app

  test "project frames score highest" do
    frame = "    (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.run/1"
    assert FrameScorer.score(frame, @app_name, 0) >= 100
  end

  test "OTP/stdlib frames score low" do
    frame = "    (stdlib 5.0) gen_server.erl:1234: :gen_server.handle_msg/6"
    assert FrameScorer.score(frame, @app_name, 0) <= 0
  end

  test "dependency frames score medium" do
    frame = "    (phoenix 1.7.0) lib/phoenix/endpoint.ex:10: Phoenix.Endpoint.call/2"
    score = FrameScorer.score(frame, @app_name, 0)
    assert score > 0 and score < 100
  end

  test "position penalty reduces score for distant frames" do
    frame = "    (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.run/1"
    score_0 = FrameScorer.score(frame, @app_name, 0)
    score_5 = FrameScorer.score(frame, @app_name, 5)
    assert score_0 > score_5
  end

  test "select_top_frames keeps at most max_frames" do
    frames =
      for i <- 1..10 do
        "    (my_app 0.1.0) lib/my_app/mod#{i}.ex:#{i}: MyApp.Mod#{i}.f/0"
      end

    result = FrameScorer.select_top_frames(frames, @app_name, max_frames: 4)
    assert length(result) == 4
  end

  test "select_top_frames prefers project frames over OTP" do
    frames = [
      "    (stdlib 5.0) gen_server.erl:100: :gen_server.handle_msg/6",
      "    (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.run/1",
      "    (elixir 1.17.0) lib/enum.ex:1: Enum.map/2"
    ]

    result = FrameScorer.select_top_frames(frames, @app_name, max_frames: 1)
    assert length(result) == 1
    assert hd(result) =~ "my_app"
  end
end
