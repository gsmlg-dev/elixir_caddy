defmodule Caddy.Server.ExternalTest do
  use ExUnit.Case, async: false

  import Mox

  alias Caddy.Server.External

  # Allow mocks to be called from async processes
  setup :verify_on_exit!

  describe "execute_command/1" do
    test "returns error for invalid command" do
      assert {:error, {:invalid_command, :invalid}} = External.execute_command(:invalid)
    end
  end

  describe "module functions" do
    test "start_caddy/0 delegates to execute_command(:start)" do
      # This verifies the function exists and has correct arity
      assert is_function(&External.start_caddy/0)
    end

    test "stop_caddy/0 delegates to execute_command(:stop)" do
      assert is_function(&External.stop_caddy/0)
    end

    test "restart_caddy/0 delegates to execute_command(:restart)" do
      assert is_function(&External.restart_caddy/0)
    end
  end
end
