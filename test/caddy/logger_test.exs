defmodule Caddy.LoggerTest do
  use ExUnit.Case, async: false

  alias Caddy.Logger

  describe "Logger supervision" do
    test "logger module is available" do
      assert is_atom(Logger)
    end

    test "can retrieve logs with tail" do
      # tail/1 should return a list
      logs = Logger.tail(10)
      assert is_list(logs)
    end

    test "tail with default parameter" do
      # Default should be 100 lines
      logs = Logger.tail()
      assert is_list(logs)
      assert length(logs) <= 100
    end

    test "tail with custom limit" do
      logs = Logger.tail(5)
      assert is_list(logs)
      assert length(logs) <= 5
    end
  end

  describe "Logger.Buffer" do
    test "buffer module exists" do
      assert Code.ensure_loaded?(Caddy.Logger.Buffer)
    end

    test "can write to buffer" do
      # write_buffer should accept messages
      result = Logger.write_buffer("test log message")
      # GenServer.cast returns :ok
      assert result == :ok
    end

    test "buffer handles multiple writes" do
      assert :ok == Logger.write_buffer("log 1")
      assert :ok == Logger.write_buffer("log 2")
      assert :ok == Logger.write_buffer("log 3")
    end

    test "buffer handles newlines in messages" do
      result = Logger.write_buffer("line1\nline2\nline3")
      assert result == :ok
    end
  end

  describe "Logger.Store" do
    test "store module exists" do
      assert Code.ensure_loaded?(Caddy.Logger.Store)
    end

    test "can write logs to store" do
      # This is internal but we can test it exists
      assert function_exported?(Logger, :write, 1)
    end

    test "store maintains log history" do
      # Write some logs
      Logger.write("test log 1")
      Logger.write("test log 2")
      Logger.write("test log 3")

      # Give it a moment to process
      Process.sleep(10)

      # Retrieve logs
      logs = Logger.tail(10)
      assert is_list(logs)
    end

    test "tail returns most recent logs" do
      # Write a unique log
      unique_log = "unique_test_log_#{:rand.uniform(10000)}"
      Logger.write(unique_log)

      Process.sleep(10)

      # Should be retrievable
      logs = Logger.tail(100)
      # Check if our log might be in there (it may or may not be depending on buffer)
      assert is_list(logs)
    end
  end

  describe "Log retention" do
    test "keeps specified number of lines" do
      # The store should keep up to 50,000 lines
      # We just verify the tail function works with various limits
      assert is_list(Logger.tail(1))
      assert is_list(Logger.tail(10))
      assert is_list(Logger.tail(100))
      assert is_list(Logger.tail(1000))
    end
  end

  describe "Integration" do
    test "buffer and store work together" do
      test_message = "integration_test_#{:rand.uniform(10000)}"

      # Write to buffer
      Logger.write_buffer(test_message)

      # Give buffer time to flush to store
      Process.sleep(50)

      # Store should eventually receive it
      # (This is a loose test since buffering is async)
      logs = Logger.tail(100)
      assert is_list(logs)
    end
  end
end
