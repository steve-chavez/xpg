{ stdenv, lib, makeWrapper, fetchurl, writeShellScriptBin, findutils, entr, lcov, gnused, gdb, writeText, ourPg, checked-shell-script } :
let
  isLinux = stdenv.isLinux;
  gdbConf = writeText "gdbconf" ''
    # Do this so we can do `backtrace` once a segfault occurs. Otherwise once SIGSEGV is received the bgworker will quit and we can't backtrace.
    handle SIGSEGV stop nopass
  '';
  xpg = checked-shell-script
  {
    name = "xpg";
    docs = "Develop native PostgreSQL extensions";
    args = [
      "ARG_POSITIONAL_SINGLE([operation], [Operation])"
      "ARG_TYPE_GROUP_SET([OPERATION], [OPERATION], [operation], [build,test,coverage,psql,gdb])"
      "ARG_OPTIONAL_SINGLE([version], [v], [PostgreSQL version], [17])"
      "ARG_TYPE_GROUP_SET([VERSION], [VERSION], [version], [17,16,15,14,13,12])"
      "ARG_LEFTOVERS([psql arguments])"
    ];
  }
  ''
  case "$_arg_version" in
    17)
      export PATH=${ourPg.postgresql_17}/bin:"$PATH"
      ;;
    16)
      export PATH=${ourPg.postgresql_16}/bin:"$PATH"
      ;;
    15)
      export PATH=${ourPg.postgresql_15}/bin:"$PATH"
      ;;
    14)
      export PATH=${ourPg.postgresql_14}/bin:"$PATH"
      ;;
    13)
      export PATH=${ourPg.postgresql_13}/bin:"$PATH"
      ;;
    12)
      export PATH=${ourPg.postgresql_12}/bin:"$PATH"
      ;;
  esac

  export BUILD_DIR="build-$_arg_version"

  # fail fast for gdb command requirement
  pid_file_name="$BUILD_DIR"/bgworker.pid

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

      make COVERAGE=1
      ;;

    gdb)
      # not required here, do nothing
      ;;

    *)
      make
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

    PGTZ=UTC initdb --no-locale --encoding=UTF8 --nosync -U "$PGUSER"

    init_script=./test/init.sh

    if [ -f $init_script ]; then
      bash $init_script
    fi

    # pg versions older than 16 don't support adding "-c" to initdb to add these options
    # so we just modify the resulting postgresql.conf to avoid an error
    {
      echo "dynamic_library_path='\$libdir:$(pwd)/$BUILD_DIR'"
      echo "extension_control_path='\$system:$(pwd)/$BUILD_DIR'"
      echo "include 'init.conf'"
    } >> "$PGDATA"/postgresql.conf

    init_conf=./test/init.conf

    if [ -f $init_conf ]; then
      cp $init_conf "$tmpdir"/init.conf
      sed -i "s|@TMPDIR@|$tmpdir|g" "$tmpdir"/init.conf
    else
      touch "$tmpdir"/init.conf
    fi

    options="-F -c listen_addresses=\"\" -k $PGDATA"

    pg_ctl start -o "$options"

    createdb contrib_regression

    init_file=test/init.sql

    if [ -f $init_file ]; then
      psql -v ON_ERROR_STOP=1 -f $init_file -d contrib_regression
    fi

    if [ -f $init_conf ]; then
      bgworker_name=$(grep '^shared_preload_libraries=' "$init_conf" | cut -d'=' -f2- | tr -d "'" || true)

      if [ ! "$bgworker_name" ]; then
        # save pid for future gdb invocation
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
