defmodule ExCompact.RegistryTest do
  use ExUnit.Case

  @test_registry_path "/tmp/ex_compact_registry_test_#{System.pid()}.json"

  setup do
    File.rm(@test_registry_path)
    on_exit(fn -> File.rm(@test_registry_path) end)
    :ok
  end

  test "register and find a node" do
    ExCompact.Registry.register("/home/user/my_project", :"myapp@localhost",
      registry_path: @test_registry_path
    )

    assert {:ok, :"myapp@localhost"} =
             ExCompact.Registry.find_node("/home/user/my_project",
               registry_path: @test_registry_path
             )
  end

  test "find_node returns :error for unknown path" do
    assert :error =
             ExCompact.Registry.find_node("/nonexistent",
               registry_path: @test_registry_path
             )
  end

  test "unregister removes entry" do
    ExCompact.Registry.register("/home/user/proj", :"app@host",
      registry_path: @test_registry_path
    )

    ExCompact.Registry.unregister("/home/user/proj",
      registry_path: @test_registry_path
    )

    assert :error =
             ExCompact.Registry.find_node("/home/user/proj",
               registry_path: @test_registry_path
             )
  end
end
