defmodule ExCompact.Patterns.DbDisconnectTest do
  use ExUnit.Case, async: true

  alias ExCompact.Patterns.DbDisconnect

  @postgrex_disconnect """
  13:49:50.389 [error] Postgrex.Protocol (#PID<0.531.0> ("db_conn_4")) disconnected: ** (DBConnection.ConnectionError) owner #PID<0.2251.0> exited

  Client #PID<0.557.0> (ExCortex.AppTelemetry) is still using a connection from owner at location:

      :erlang.port_command/3
      :prim_inet.send/4
      (postgrex 0.22.0) lib/postgrex/protocol.ex:3359: Postgrex.Protocol.do_send/3
      (postgrex 0.22.0) lib/postgrex/protocol.ex:2252: Postgrex.Protocol.rebind_execute/4
      (ecto_sql 3.13.5) lib/ecto/adapters/sql/sandbox.ex:412: Ecto.Adapters.SQL.Sandbox.Connection.proxy/3
      (db_connection 2.9.0) lib/db_connection/holder.ex:356: DBConnection.Holder.holder_apply/4
      (db_connection 2.9.0) lib/db_connection.ex:1539: DBConnection.run_execute/5
      (db_connection 2.9.0) lib/db_connection.ex:1587: DBConnection.run_with_retries/5
      (db_connection 2.9.0) lib/db_connection.ex:791: DBConnection.parsed_prepare_execute/5
      (db_connection 2.9.0) lib/db_connection.ex:783: DBConnection.prepare_execute/4
      (ecto_sql 3.13.5) lib/ecto/adapters/postgres/connection.ex:108: Ecto.Adapters.Postgres.Connection.prepare_execute/5
      (ecto_sql 3.13.5) lib/ecto/adapters/sql.ex:1019: Ecto.Adapters.SQL.execute!/5
      (ecto_sql 3.13.5) lib/ecto/adapters/sql.ex:1011: Ecto.Adapters.SQL.execute/6
      (ecto 3.13.5) lib/ecto/repo/queryable.ex:241: Ecto.Repo.Queryable.execute/4
      (ecto 3.13.5) lib/ecto/repo/queryable.ex:19: Ecto.Repo.Queryable.all/3
      (ecto 3.13.5) lib/ecto/repo/queryable.ex:163: Ecto.Repo.Queryable.one/3
      (ex_cortex 0.1.0) lib/ex_cortex/app_telemetry.ex:276: ExCortex.AppTelemetry.fetch_rumination_name/1
      (ex_cortex 0.1.0) lib/ex_cortex/app_telemetry.ex:114: ExCortex.AppTelemetry.handle_info/2
      (stdlib 6.2.2.2) gen_server.erl:2345: :gen_server.try_handle_info/3

  The connection itself was checked out by #PID<0.557.0> (ExCortex.AppTelemetry) at location:

      (ecto_sql 3.13.5) lib/ecto/adapters/postgres/connection.ex:108: Ecto.Adapters.Postgres.Connection.prepare_execute/5
      (ecto_sql 3.13.5) lib/ecto/adapters/sql.ex:1019: Ecto.Adapters.SQL.execute!/5
      (ecto_sql 3.13.5) lib/ecto/adapters/sql.ex:1011: Ecto.Adapters.SQL.execute/6
      (ecto 3.13.5) lib/ecto/repo/queryable.ex:241: Ecto.Repo.Queryable.execute/4
      (ecto 3.13.5) lib/ecto/repo/queryable.ex:19: Ecto.Repo.Queryable.all/3
      (ecto 3.13.5) lib/ecto/repo/queryable.ex:163: Ecto.Repo.Queryable.one/3
      (ex_cortex 0.1.0) lib/ex_cortex/app_telemetry.ex:276: ExCortex.AppTelemetry.fetch_rumination_name/1
      (ex_cortex 0.1.0) lib/ex_cortex/app_telemetry.ex:114: ExCortex.AppTelemetry.handle_info/2
      (stdlib 6.2.2.2) gen_server.erl:2345: :gen_server.try_handle_info/3
      (stdlib 6.2.2.2) gen_server.erl:2433: :gen_server.handle_msg/6
      (stdlib 6.2.2.2) proc_lib.erl:329: :proc_lib.init_p_do_apply/3

  """

  test "compacts Postgrex disconnect to just the header line" do
    result = DbDisconnect.compact(@postgrex_disconnect, [])

    # Header preserved
    assert result =~ "Postgrex.Protocol"
    assert result =~ "disconnected:"
    assert result =~ "DBConnection.ConnectionError"

    # All the verbose stack traces stripped
    refute result =~ "Client #PID"
    refute result =~ "is still using a connection"
    refute result =~ "The connection itself was checked out"
    refute result =~ "DBConnection.Holder.holder_apply"
    refute result =~ ":gen_server.try_handle_info"
  end

  test "passes through text with no disconnects" do
    input = "Normal output"
    assert DbDisconnect.compact(input, []) == input
  end
end
