defmodule Caddy.Server.EmbeddedTest do
  use ExUnit.Case, async: false

  alias Caddy.Config
  alias Caddy.Server.Embedded

  @tag :tmp_dir
  test "terminates the port process with SIGTERM before falling back to SIGKILL", %{
    tmp_dir: tmp_dir
  } do
    marker_path = Path.join(tmp_dir, "term-received")
    ready_path = Path.join(tmp_dir, "ready")
    original_pid_file = Application.get_env(:caddy, :pid_file)
    perl = System.find_executable("perl") || flunk("perl is required for this signal test")

    Application.put_env(:caddy, :pid_file, Path.join(tmp_dir, "caddy.pid"))

    port =
      Port.open({:spawn_executable, perl}, [
        {:args, ["-e", trap_script(), marker_path, ready_path]},
        :binary,
        :exit_status
      ])

    try do
      assert {:os_pid, _pid} = Port.info(port, :os_pid)
      assert eventually(fn -> File.exists?(ready_path) end)
      Embedded.terminate(:shutdown, %{port: port})
      assert File.read!(marker_path) =~ "term"
    after
      restore_env(:pid_file, original_pid_file)

      if File.exists?(Config.pid_file()) do
        File.rm(Config.pid_file())
      end
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:caddy, key)
  defp restore_env(key, value), do: Application.put_env(:caddy, key, value)

  defp trap_script do
    """
    my ($marker, $ready) = @ARGV;
    $SIG{TERM} = sub {
      open(my $fh, '>', $marker) or die $!;
      print $fh "term\\n";
      close($fh);
      exit 0;
    };
    open(my $ready_fh, '>', $ready) or die $!;
    print $ready_fh "ready\\n";
    close($ready_fh);
    while (1) { sleep 10; }
    """
  end

  defp eventually(fun, attempts \\ 20)

  defp eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      true
    else
      Process.sleep(25)
      eventually(fun, attempts - 1)
    end
  end

  defp eventually(_fun, 0), do: false
end
