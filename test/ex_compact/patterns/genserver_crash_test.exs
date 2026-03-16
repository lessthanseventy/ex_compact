defmodule ExCompact.Patterns.GenServerCrashTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.GenServerCrash

  @sample_crash """
  [error] GenServer MyApp.Worker terminating
  ** (RuntimeError) something broke
      (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.handle_info/2
      (stdlib 5.0) gen_server.erl:1123: :gen_server.try_dispatch/4
      (stdlib 5.0) gen_server.erl:1200: :gen_server.handle_msg/6
      (stdlib 5.0) proc_lib.erl:250: :proc_lib.init_p_do_apply/3
  Last message: :tick
  State: %{counter: 42, data: "a very long string that goes on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on"}
  """

  test "compacts GenServer crash to module + exception + project frames + last message" do
    result = GenServerCrash.compact(@sample_crash, app: :my_app, max_frames: 2)
    assert result =~ "GenServer MyApp.Worker terminating"
    assert result =~ "RuntimeError"
    assert result =~ "MyApp.Worker.handle_info/2"
    assert result =~ "Last message: :tick"
    refute result =~ ":gen_server.try_dispatch/4"
    refute result =~ ":proc_lib.init_p_do_apply/3"
  end

  test "truncates large state" do
    result = GenServerCrash.compact(@sample_crash, app: :my_app)
    if result =~ "State:" do
      state_line = result |> String.split("\n") |> Enum.find(&(&1 =~ "State:"))
      assert String.length(state_line) < 200
    end
  end

  test "passes through text with no crash reports" do
    input = "Normal log output"
    assert GenServerCrash.compact(input, []) == input
  end
end
