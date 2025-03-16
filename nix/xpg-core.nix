{ stdenv, lib, makeWrapper, fetchurl, writeShellScriptBin, findutils, entr, lcov, gnused, gdb, writeText, ourPg, checked-shell-script, bash, gcc,
  autoconf, automake, readline, zlib, flex, bison, ccache, icu, pkg-config
} :
let
  isLinux = stdenv.isLinux;
  gdbConf = writeText "gdbconf" ''
    # Do this so we can do `backtrace` once a segfault occurs. Otherwise once SIGSEGV is received the bgworker will quit and we can't backtrace.
    handle SIGSEGV stop nopass
  '';
  xpg-core = checked-shell-script
  {
    name = "xpg-core";
    docs = "Develop PostgreSQL core";
    args = [
      "ARG_POSITIONAL_SINGLE([operation], [Operation])"
      "ARG_TYPE_GROUP_SET([OPERATION], [OPERATION], [operation], [build,test,psql])"
      "ARG_LEFTOVERS([psql arguments])"
    ];
  }
  ''
  export PATH="${lib.makeBinPath [
    autoconf
    automake
    pkg-config
    readline zlib bison icu flex
    # ... add as many as you need
  ]}:$PATH"

  export OUR_SHELL="${bash}/bin/bash"
  export CC="${ccache}/bin/ccache ${gcc}/bin/gcc"
  export BUILD_DIR="$PWD/build"

  export PATH="$BUILD_DIR"/bin:"$PATH"

  export PKG_CONFIG_PATH="${icu.dev}/lib/pkgconfig:''${PKG_CONFIG_PATH:-}"

  export PKG_CONFIG_PATH="${readline.dev}/lib/pkgconfig:''${PKG_CONFIG_PATH:-}"
  export CFLAGS="-I${readline.dev}/include ''${CFLAGS:-}"
  export LDFLAGS="-L${readline}/lib ''${LDFLAGS:-}"

  export PKG_CONFIG_PATH="${zlib.dev}/lib/pkgconfig:''${PKG_CONFIG_PATH:-}"
  export CFLAGS="-I${zlib.dev}/include ''${CFLAGS:-}"
  export LDFLAGS="-L${zlib}/lib ''${LDFLAGS:-}"

  case "$_arg_operation" in

    build)
      mkdir -p "$BUILD_DIR"

      cd "$BUILD_DIR"

      if [ ! -f "$BUILD_DIR/config.status" ]; then
        ../configure --enable-cassert --with-python --prefix "$BUILD_DIR"
      fi

      echo 'Building pg...'

      make -j16 -s
      make install -j16 -s
      ;;

    test)
      cd "$BUILD_DIR"

      make check -s
      ;;

    psql)
      tmpdir="$(mktemp -d)"

      export PGDATA="$tmpdir"
      export PGHOST="$tmpdir"
      export PGUSER=postgres
      export PGDATABASE=postgres

      trap 'pg_ctl stop -m i && rm -rf "$tmpdir"' sigint sigterm exit

      PGTZ=UTC initdb --no-locale --encoding=UTF8 --nosync -U "$PGUSER"

      options="-F -c listen_addresses=\"\" -k $PGDATA"

      pg_ctl start -o "$options"

      psql "''${_arg_leftovers[@]}"
      ;;

    esac
  '';
in
xpg-core.bin
