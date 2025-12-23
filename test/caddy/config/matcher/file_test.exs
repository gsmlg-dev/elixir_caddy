defmodule Caddy.Config.Matcher.FileTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Matcher.File
  alias Caddy.Caddyfile

  describe "new/1" do
    test "creates file matcher with try_files only" do
      matcher = File.new(try_files: ["{path}", "{path}.html"])
      assert matcher.try_files == ["{path}", "{path}.html"]
      assert matcher.root == nil
      assert matcher.try_policy == nil
      assert matcher.split_path == []
    end

    test "creates file matcher with all options" do
      matcher =
        File.new(
          root: "/srv/www",
          try_files: ["{path}", "=404"],
          try_policy: :smallest_size,
          split_path: [".php"]
        )

      assert matcher.root == "/srv/www"
      assert matcher.try_files == ["{path}", "=404"]
      assert matcher.try_policy == :smallest_size
      assert matcher.split_path == [".php"]
    end
  end

  describe "validate/1" do
    test "returns ok for valid matcher" do
      matcher = File.new(try_files: ["{path}"])
      assert {:ok, ^matcher} = File.validate(matcher)
    end

    test "returns error for empty try_files" do
      matcher = File.new(try_files: [])
      assert {:error, "try_files cannot be empty"} = File.validate(matcher)
    end

    test "returns error for non-string try_files" do
      matcher = %File{try_files: [123]}
      assert {:error, "all try_files must be strings"} = File.validate(matcher)
    end

    test "returns error for invalid try_policy" do
      matcher = %File{try_files: ["{path}"], try_policy: :invalid}
      assert {:error, "invalid try_policy: :invalid"} = File.validate(matcher)
    end

    test "accepts all valid try_policy values" do
      for policy <- [:first_exist, :smallest_size, :largest_size, :most_recently_modified] do
        matcher = File.new(try_files: ["{path}"], try_policy: policy)
        assert {:ok, ^matcher} = File.validate(matcher)
      end
    end
  end

  describe "Caddyfile protocol" do
    test "renders simple file matcher inline" do
      matcher = File.new(try_files: ["{path}"])
      assert Caddyfile.to_caddyfile(matcher) == "file try_files {path}"
    end

    test "renders file matcher with multiple options as block" do
      matcher = File.new(root: "/srv/www", try_files: ["{path}", "=404"])
      result = Caddyfile.to_caddyfile(matcher)
      assert result =~ "file {"
      assert result =~ "root /srv/www"
      assert result =~ "try_files {path} =404"
      assert result =~ "}"
    end

    test "renders file matcher with try_policy" do
      matcher = File.new(try_files: ["{path}"], try_policy: :smallest_size)
      result = Caddyfile.to_caddyfile(matcher)
      assert result =~ "try_policy smallest_size"
    end

    test "renders file matcher with split_path" do
      matcher = File.new(try_files: ["{path}"], split_path: [".php", ".html"])
      result = Caddyfile.to_caddyfile(matcher)
      assert result =~ "split_path .php .html"
    end
  end
end
