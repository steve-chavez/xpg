with import (builtins.fetchTarball {
    name = "24.05"; # May 31 2024
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/24.05.tar.gz";
    sha256 = "sha256:1lr1h35prqkd1mkmzriwlpvxcb34kmhc9dnr48gkm8hh089hifmx";
}) {};
let
  xpgPkgs = import ../default.nix;
  pgsqlcheck15 = callPackage ../nix/plpgsql-check.nix {
    postgresql = xpgPkgs.postgresql_15;
  };
in
{
  xpg = xpgPkgs.xpg.withExtensions {
    extensions = {
      "15" = [ pgsqlcheck15 ];
    };
  };
}
