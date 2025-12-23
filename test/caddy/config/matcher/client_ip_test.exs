defmodule Caddy.Config.Matcher.ClientIpTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.ClientIp
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates client_ip matcher with single range" do
      matcher = ClientIp.new(["192.168.1.0/24"])
      assert matcher.ranges == ["192.168.1.0/24"]
    end

    test "creates client_ip matcher with multiple ranges" do
      matcher = ClientIp.new(["192.168.1.0/24", "10.0.0.0/8"])
      assert matcher.ranges == ["192.168.1.0/24", "10.0.0.0/8"]
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      matcher = ClientIp.new(["192.168.1.0/24"])
      assert {:ok, ^matcher} = ClientIp.validate(matcher)
    end

    test "returns error for empty ranges" do
      matcher = ClientIp.new([])
      assert {:error, "ranges cannot be empty"} = ClientIp.validate(matcher)
    end

    test "returns error for non-string ranges" do
      matcher = %ClientIp{ranges: [123]}
      assert {:error, "all ranges must be strings"} = ClientIp.validate(matcher)
    end
  end

  describe "Caddyfile protocol" do
    test "renders single range" do
      matcher = ClientIp.new(["192.168.1.0/24"])
      assert Caddyfile.to_caddyfile(matcher) == "client_ip 192.168.1.0/24"
    end

    test "renders multiple ranges" do
      matcher = ClientIp.new(["192.168.1.0/24", "10.0.0.0/8"])
      assert Caddyfile.to_caddyfile(matcher) == "client_ip 192.168.1.0/24 10.0.0.0/8"
    end
  end
end
