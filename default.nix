{
  lib,
  pkgs,
  beamPackages,
  nodejs,
  ...
}: let
  pname = "elixir_caddy";
  version = "1.0.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = ./.;
  };

  mixFodDeps = beamPackages.fetchMixDeps {
    pname = "${pname}-mix-deps";
    inherit src version;
    # nix will complain and tell you the right value to replace this with
    hash = "sha256-CIceAuuNZFlUCHywj4N3pFvQpGT8SqjfT7IftUfhz2o=";
    mixEnv = "prod"; # default is "prod", when empty includes all dependencies, such as "dev", "test".
    # if you have build time environment variables add them here
    RELEASE_COOKIE="elixir-caddy-program!";
  };
in
  beamPackages.mixRelease {
    inherit pname version src mixFodDeps;

    nativeBuildInputs = [
    ];

    preBuild = ''
    '';

    postBuild = ''
    '';

    meta = with lib; {
      description = "Run Caddy in Elixir app";
      mainProgram = "elixir_caddy";
    };
  }
