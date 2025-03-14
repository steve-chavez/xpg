with import (builtins.fetchTarball {
    name = "24.05"; # May 31 2024
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/24.05.tar.gz";
    sha256 = "sha256:1lr1h35prqkd1mkmzriwlpvxcb34kmhc9dnr48gkm8hh089hifmx";
}) {};
let
  ourPg = callPackage ./nix/postgresql {
    inherit lib;
    inherit stdenv;
    inherit fetchurl;
    inherit makeWrapper;
    inherit callPackage;
  };
  checked-shell-script = callPackage ./nix/checked-shell-script.nix {
    inherit lib;
  };
  xpg = callPackage ./nix/xpg.nix {
    inherit ourPg;
    inherit checked-shell-script;
  };
in
xpg
