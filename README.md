# xpg

```
$ xpg-core -h
Usage: xpg-core [-h|--help] [--] <operation> ...
        <operation>: Operation. Can be one of: 'build', 'test', 'tap', 'psql', and 'docs'
        -h, --help: Prints help

Develop PostgreSQL core
```

```
$ xpg -h
Usage: xpg [-h|--help] [-v|--version <VERSION>] [--] <operation> ...
        <operation>: Operation. Can be one of: 'build', 'test', 'coverage', 'psql' and 'gdb'
        ... : psql arguments
        -h, --help: Prints help
        -v, --version: PostgreSQL version. Can be one of: '17', '16', '15', '14', '13' and '12' (default: '17')

Develop native PostgreSQL extensions
```
