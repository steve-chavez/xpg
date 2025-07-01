with import (builtins.fetchTarball {
    name = "24.05"; # May 31 2024
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/24.05.tar.gz";
    sha256 = "sha256:1lr1h35prqkd1mkmzriwlpvxcb34kmhc9dnr48gkm8hh089hifmx";
}) {};
let
  ourPg = callPackage ../nix/postgresql {
    inherit lib;
    inherit stdenv;
    inherit fetchurl;
    inherit makeWrapper;
    inherit callPackage;
  };
  checked-shell-script = callPackage ../nix/checked-shell-script.nix {
    inherit lib;
  };
  xpg = callPackage ../nix/xpg.nix {
    inherit ourPg;
    inherit checked-shell-script;
  };
  pgsqlcheck15 = callPackage ../nix/plpgsql-check.nix {
    postgresql = ourPg.postgresql_15;
  };
  # TODO: this is duplicated with root/default.nix
  xpgWithExtensions =
    { exts12 ? [] , exts13 ? [] , exts14 ? [], exts15 ? [], exts16? [], exts17? [], exts18? [] } :
    callPackage ../nix/xpg.nix {
      inherit ourPg;
      inherit checked-shell-script;
      inherit exts12;
      inherit exts13;
      inherit exts14;
      inherit exts15;
      inherit exts16;
      inherit exts17;
      inherit exts18;
    };
in
{
  xpg = (xpgWithExtensions { exts15 = [ pgsqlcheck15 ]; });
}
