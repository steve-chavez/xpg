{
  stdenv, lib, makeWrapper, fetchurl, writeShellScriptBin, findutils, entr, lcov, gnused,
  gdb, writeText, ourPg, checked-shell-script,
  exts12? [], exts13? [], exts14? [], exts15? [], exts16? [], exts17? [], exts18? []
} :
let
  isLinux = stdenv.isLinux;
  gdbConf = writeText "gdbconf" ''
    # Do this so we can do `backtrace` once a segfault occurs. Otherwise once SIGSEGV is received the bgworker will quit and we can't backtrace.
    handle SIGSEGV stop nopass
  '';
  buildExtPaths = exts: builtins.concatStringsSep ":" (exts ++ ["$(pwd)/$BUILD_DIR"]); # also append the local build directory
  xpg = checked-shell-script
  {
    name = "xpg";
    docs = "Develop native PostgreSQL extensions";
    args = [
      "ARG_POSITIONAL_SINGLE([operation], [Operation])"
      "ARG_TYPE_GROUP_SET([OPERATION], [OPERATION], [operation], [build,test,coverage,psql,gdb])"
      "ARG_OPTIONAL_SINGLE([version], [v], [PostgreSQL version], [17])"
      "ARG_TYPE_GROUP_SET([VERSION], [VERSION], [version], [18,17,16,15,14,13,12])"
      "ARG_LEFTOVERS([psql arguments])"
    ];
  }
  ''
  export BUILD_DIR="build-$_arg_version" # this needs to be exported so external `make` commands pick it up

  case "$_arg_version" in
    18)
      export PATH=${ourPg.postgresql_18}/bin:"$PATH"
      _ext_paths=${buildExtPaths exts18}
      ;;
    17)
      export PATH=${ourPg.postgresql_17}/bin:"$PATH"
      _ext_paths=${buildExtPaths exts17}
      ;;
    16)
      export PATH=${ourPg.postgresql_16}/bin:"$PATH"
      _ext_paths=${buildExtPaths exts16}
      ;;
    15)
      export PATH=${ourPg.postgresql_15}/bin:"$PATH"
      _ext_paths=${buildExtPaths exts15}
      ;;
    14)
      export PATH=${ourPg.postgresql_14}/bin:"$PATH"
      _ext_paths=${buildExtPaths exts14}
      ;;
    13)
      export PATH=${ourPg.postgresql_13}/bin:"$PATH"
      _ext_paths=${buildExtPaths exts13}
      ;;
    12)
      export PATH=${ourPg.postgresql_12}/bin:"$PATH"
      _ext_paths=${buildExtPaths exts12}
      ;;
  esac

  EXT_DYNLIB_PATHS="$_ext_paths"
  EXT_CONTROL_PATHS="$_ext_paths"

  pid_file_name="$BUILD_DIR"/bgworker.pid

  # fail fast for gdb command requirement
  if [ "$_arg_operation" == gdb ] && [ ! -e "$pid_file_name" ]; then
      echo 'The background worker is not started. First you have to run "xpg psql".'
      exit 1
  fi

  COVERAGE_INFO=$BUILD_DIR/coverage.info

  # commands that require the build ready
  case "$_arg_operation" in
    coverage)
      if [ ! -f "$COVERAGE_INFO" ]; then
        rm -rf "$BUILD_DIR"/*.o "$BUILD_DIR"/*.so
      fi

      make build COVERAGE=1
      ;;

    gdb)
      # not required here, do nothing
      ;;

    *)
      make build
      ;;
  esac

  # commands that require a temp db
  if [ "$_arg_operation" != build ] && [ "$_arg_operation" != gdb ]; then
    tmpdir="$(mktemp -d)"

    export TMPDIR="$tmpdir"
    export PGDATA="$tmpdir"
    export PGHOST="$tmpdir"
    export PGUSER=postgres
    export PGDATABASE=postgres

    trap 'pg_ctl stop -m i && rm -rf "$tmpdir" && rm -rf "$pid_file_name"' sigint sigterm exit

    PGTZ=UTC initdb -A trust --no-locale --encoding=UTF8 --nosync -U "$PGUSER"

    init_script=./test/init.sh

    if [ -f $init_script ]; then
      bash $init_script
    fi

    init_conf=./test/init.conf

    if [ -f $init_conf ]; then
      cp $init_conf "$tmpdir"/init.conf
      sed -i "s|@TMPDIR@|$tmpdir|g" "$tmpdir"/init.conf
    else
      touch "$tmpdir"/init.conf
    fi

    # pg versions older than 16 don't support adding "-c" to initdb to add these options
    # so we just modify the resulting postgresql.conf to avoid an error
    {
      echo "dynamic_library_path='\$libdir:$EXT_DYNLIB_PATHS'"
      echo "extension_control_path='\$system:$EXT_CONTROL_PATHS'"
      echo "include 'init.conf'"
    } >> "$PGDATA"/postgresql.conf

    options="-F -c listen_addresses=\"\" -k $PGDATA"

    pg_ctl start -l server.log -o "$options"

    init_file=test/init.sql

    # if not psql command just use the contrib_regression database for test running
    if [ "$_arg_operation" != psql ]; then
      createdb contrib_regression

      if [ -f $init_file ]; then
        psql -v ON_ERROR_STOP=1 -f $init_file -d contrib_regression
      fi
    else # else use the default postgres db

      # TODO: if psql uses a different database, the init file and the pid file name creation won't work
      if [ -f $init_file ]; then
        psql -v ON_ERROR_STOP=1 -f $init_file
      fi

      # create a pid file in case the psql command is used, for later analysis
      bgworker_name=$(grep -oP '^EXTENSION\s*=\s*\K\S+' Makefile) # TODO: assumes the bgworker has the same name as the extension on the Makefile

      if [ -n "$bgworker_name" ]; then
        # save pid for future invocation
        psql -t -c "\o $pid_file_name" -c "select pid from pg_stat_activity where backend_type ilike '%$bgworker_name%'"
        ${gnused}/bin/sed '/^''$/d;s/[[:blank:]]//g' -i "$pid_file_name"
      fi
    fi

  fi

  case "$_arg_operation" in
    build)
      # do nothing here as the build already ran
      ;;

    test)
      make test
      ;;

    coverage)
      coverage_out_dir=$BUILD_DIR/coverage_html

      make test

      ${lcov}/bin/lcov --capture --directory . --output-file "$COVERAGE_INFO"

      # remove postgres headers on the nix store, otherwise they show on the output
      ${lcov}/bin/lcov --remove "$COVERAGE_INFO" '/nix/*' --output-file "$COVERAGE_INFO" || true

      ${lcov}/bin/lcov --list "$COVERAGE_INFO"
      ${lcov}/bin/genhtml "$COVERAGE_INFO" --output-directory "$coverage_out_dir"

      echo -e "\nTo see the results, visit file://$(pwd)/$coverage_out_dir/index.html on your browser\n"
      ;;

    psql)
      psql "''${_arg_leftovers[@]}"
      ;;

    gdb)

      ${
        if isLinux
        then  ''
          if [ "$EUID" != 0 ]; then
            echo 'Prefix the command with "sudo", gdb requires elevated privileges to debug processes.'
            exit 1
          fi

          pid=$(cat "$pid_file_name")
          if [ -z "$pid" ]; then
            echo "There's no background worker found for the extension."
            exit 1
          fi
          ${gdb}/bin/gdb -x ${gdbConf} -p "$pid" "''${_arg_leftovers[@]}"
        ''
        else ''
          echo 'gdb command only works on Linux'
          exit 1
        ''
      }
      ;;

    esac
  '';
in
xpg.bin
