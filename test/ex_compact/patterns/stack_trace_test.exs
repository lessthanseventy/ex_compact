defmodule ExCompact.Patterns.StackTraceTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.StackTrace

  @sample_trace """
  ** (RuntimeError) something went wrong
      (my_app 0.1.0) lib/my_app/worker.ex:42: MyApp.Worker.run/1
      (my_app 0.1.0) lib/my_app/server.ex:10: MyApp.Server.handle_call/3
      (stdlib 5.0) gen_server.erl:1123: :gen_server.try_dispatch/4
      (stdlib 5.0) gen_server.erl:1200: :gen_server.handle_msg/6
      (stdlib 5.0) proc_lib.erl:250: :proc_lib.init_p_do_apply/3
      (elixir 1.17.0) lib/enum.ex:1: Enum.map/2
      (elixir 1.17.0) lib/kernel.ex:100: Kernel.apply/3
  """

  test "compacts a stack trace to exception + top project frames" do
    result = StackTrace.compact(@sample_trace, app: :my_app, max_frames: 4)
    assert result =~ "** (RuntimeError) something went wrong"
    assert result =~ "MyApp.Worker.run/1"
    assert result =~ "MyApp.Server.handle_call/3"
    refute result =~ ":gen_server.try_dispatch/4"
    refute result =~ ":proc_lib.init_p_do_apply/3"
  end

  test "passes through text with no stack traces" do
    input = "Just normal output\nnothing special"
    assert StackTrace.compact(input, []) == input
  end

  test "handles multiple stack traces in one text" do
    input = """
    Some output before
    ** (ArgumentError) bad arg
        (my_app 0.1.0) lib/my_app/a.ex:1: MyApp.A.f/0
        (stdlib 5.0) gen_server.erl:100: :gen_server.handle_msg/6
    Some middle text
    ** (KeyError) key :foo not found
        (my_app 0.1.0) lib/my_app/b.ex:2: MyApp.B.g/1
        (stdlib 5.0) gen_server.erl:200: :gen_server.handle_msg/6
    Some output after
    """
    result = StackTrace.compact(input, app: :my_app)
    assert result =~ "** (ArgumentError)"
    assert result =~ "** (KeyError)"
    assert result =~ "MyApp.A.f/0"
    assert result =~ "MyApp.B.g/1"
    refute result =~ ":gen_server.handle_msg/6"
  end
end
