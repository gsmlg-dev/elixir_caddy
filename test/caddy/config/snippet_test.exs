defmodule Caddy.Config.SnippetTest do
  use ExUnit.Case, async: true

  alias Caddy.Config.Snippet
  alias Caddy.Caddyfile

  describe "new/3" do
    test "creates snippet with name and content" do
      snippet = Snippet.new("test", "respond 200")

      assert snippet.name == "test"
      assert snippet.content == "respond 200"
      assert snippet.description == nil
    end

    test "creates snippet with description" do
      snippet = Snippet.new("test", "respond 200", description: "Test snippet")

      assert snippet.description == "Test snippet"
    end

    test "trims content whitespace" do
      snippet = Snippet.new("test", "  respond 200  \n")

      assert snippet.content == "respond 200"
    end
  end

  describe "Caddyfile protocol" do
    test "renders simple snippet" do
      snippet = Snippet.new("test", "respond 200")
      result = Caddyfile.to_caddyfile(snippet)

      assert result == "(test) {\n  respond 200\n}"
    end

    test "renders snippet with multiline content" do
      snippet =
        Snippet.new("log-zone", """
        log {
          format json
          output file /var/log/access.log
        }
        """)

      result = Caddyfile.to_caddyfile(snippet)

      assert result =~ "(log-zone) {"
      assert result =~ "  log {"
      assert result =~ "    format json"
      assert result =~ "    output file /var/log/access.log"
    end

    test "preserves argument placeholders" do
      snippet = Snippet.new("log-zone", """
      log {
        output file /srv/logs/{args[0]}/{args[1]}/access.log
      }
      """)

      result = Caddyfile.to_caddyfile(snippet)

      assert result =~ "{args[0]}"
      assert result =~ "{args[1]}"
    end

    test "handles empty lines correctly" do
      snippet =
        Snippet.new("test", """
        line1

        line2
        """)

      result = Caddyfile.to_caddyfile(snippet)

      assert result =~ "  line1"
      assert result =~ "\n\n"
      assert result =~ "  line2"
    end

    test "renders complex snippet from user example" do
      snippet =
        Snippet.new("log-zone", """
        log {
          format json
          output file /srv/logs/{args[0]}/{args[1]}/access.log {
            roll_size 50mb
            roll_keep 5
            roll_keep_for 720h
          }
        }
        """)

      result = Caddyfile.to_caddyfile(snippet)

      assert result =~ "(log-zone) {"
      assert result =~ "  log {"
      assert result =~ "    format json"
      assert result =~ "    output file /srv/logs/{args[0]}/{args[1]}/access.log {"
      assert result =~ "      roll_size 50mb"
      assert result =~ "      roll_keep 5"
      assert result =~ "      roll_keep_for 720h"
    end
  end
end
