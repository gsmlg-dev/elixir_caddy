defmodule Caddy.Config.Matcher.RemoteIpTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.RemoteIp
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates remote_ip matcher with single range" do
      matcher = RemoteIp.new(["192.168.1.0/24"])
      assert matcher.ranges == ["192.168.1.0/24"]
    end

    test "creates remote_ip matcher with multiple ranges" do
      matcher = RemoteIp.new(["192.168.1.0/24", "10.0.0.0/8", "172.16.0.0/12"])
      assert matcher.ranges == ["192.168.1.0/24", "10.0.0.0/8", "172.16.0.0/12"]
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      matcher = RemoteIp.new(["192.168.1.0/24"])
      assert {:ok, ^matcher} = RemoteIp.validate(matcher)
    end

    test "returns error for empty ranges" do
      matcher = RemoteIp.new([])
      assert {:error, "ranges cannot be empty"} = RemoteIp.validate(matcher)
    end

    test "returns error for non-string ranges" do
      matcher = %RemoteIp{ranges: [123]}
      assert {:error, "all ranges must be strings"} = RemoteIp.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders single range" do
      matcher = RemoteIp.new(["192.168.1.0/24"])
      assert Caddyfile.to_caddyfile(matcher) == "remote_ip 192.168.1.0/24"
    end

    test "renders multiple ranges" do
      matcher = RemoteIp.new(["192.168.1.0/24", "10.0.0.0/8"])
      assert Caddyfile.to_caddyfile(matcher) == "remote_ip 192.168.1.0/24 10.0.0.0/8"
    end
  end
end
