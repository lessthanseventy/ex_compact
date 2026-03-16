defmodule ExCompact.Patterns.ProcessCrashTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.ProcessCrash

  @task_crash """
  [error] Task #PID<0.123.0> started from MyApp.Server terminating
  ** (RuntimeError) task failed
      (my_app 0.1.0) lib/my_app/task_worker.ex:15: MyApp.TaskWorker.run/1
      (elixir 1.17.0) lib/task/supervised.ex:101: Task.Supervised.invoke_mfa/2
      (stdlib 5.0) proc_lib.erl:250: :proc_lib.init_p_do_apply/3
  Function: &MyApp.TaskWorker.run/1
      Args: [:some_arg]
  """

  @supervisor_crash """
  [error] Child MyApp.Worker of Supervisor MyApp.WorkerSupervisor terminated
  ** (exit) an exception was raised:
      ** (RuntimeError) worker crashed
          (my_app 0.1.0) lib/my_app/worker.ex:30: MyApp.Worker.init/1
          (stdlib 5.0) gen_server.erl:900: :gen_server.init_it/2
          (stdlib 5.0) proc_lib.erl:250: :proc_lib.init_p_do_apply/3
  Pid: #PID<0.456.0>
  Start Call: MyApp.Worker.start_link([])
  """

  test "compacts Task crash to header + exception + project frames" do
    result = ProcessCrash.compact(@task_crash, app: :my_app)
    assert result =~ "Task #PID<0.123.0> started from MyApp.Server terminating"
    assert result =~ "RuntimeError"
    assert result =~ "MyApp.TaskWorker.run/1"
    refute result =~ "Task.Supervised.invoke_mfa"
    refute result =~ ":proc_lib.init_p_do_apply"
  end

  test "compacts Supervisor child crash to header + exception + project frames" do
    result = ProcessCrash.compact(@supervisor_crash, app: :my_app)
    assert result =~ "Child MyApp.Worker of Supervisor MyApp.WorkerSupervisor terminated"
    assert result =~ "RuntimeError"
    assert result =~ "MyApp.Worker.init/1"
    refute result =~ ":gen_server.init_it"
    refute result =~ ":proc_lib.init_p_do_apply"
  end

  test "passes through text with no process crashes" do
    input = "Normal log output"
    assert ProcessCrash.compact(input, []) == input
  end
end
