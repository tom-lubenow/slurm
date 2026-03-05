# Slurm autoconf replacement - generates config.h and other build-time files
#
# This replaces autoconf/configure for nixnative builds by:
# 1. Parsing the META file for version info
# 2. Generating config.h with platform detection
# 3. Generating slurm/slurm_version.h
# 4. Generating global_defaults.c
#
{ pkgs, lib, root }:

let
  # ==========================================================================
  # META file parsing
  # ==========================================================================

  metaFile = builtins.readFile (root + "/META");

  # Extract a value from META file format "Key: value"
  getMeta = key:
    let
      lines = lib.splitString "\n" metaFile;
      matching = lib.filter (l: lib.hasPrefix "${key}:" (lib.removePrefix "\t" (lib.removePrefix " " l))) lines;
      line = if matching != [] then builtins.head matching else "${key}:\t0";
      value = lib.removePrefix "${key}:" (lib.removePrefix "\t" (lib.removePrefix " " line));
    in lib.trim value;

  # Version components from META
  slurmMajor = getMeta "Major";
  slurmMinor = getMeta "Minor";
  slurmMicro = getMeta "Micro";
  slurmVersion = getMeta "Version";

  # API components from META
  apiCurrent = getMeta "API_CURRENT";
  apiAge = getMeta "API_AGE";
  apiRevision = getMeta "API_REVISION";

  # Calculate version numbers
  # SLURM_VERSION_NUMBER = (major << 16) + (minor << 8) + micro
  majorInt = lib.toInt slurmMajor;
  minorInt = lib.toInt slurmMinor;
  microInt = lib.toInt slurmMicro;
  versionNumber = (majorInt * 65536) + (minorInt * 256) + microInt;

  # API_MAJOR = API_CURRENT - API_AGE
  apiCurrentInt = lib.toInt apiCurrent;
  apiAgeInt = lib.toInt apiAge;
  apiRevisionInt = lib.toInt apiRevision;
  apiMajor = apiCurrentInt - apiAgeInt;
  apiVersionNumber = (apiMajor * 65536) + (apiAgeInt * 256) + apiRevisionInt;

  # ==========================================================================
  # Generated file contents
  # ==========================================================================

  configHContent = ''
    /*
     * config.h - Auto-generated configuration for nixnative builds
     *
     * Generated from META file. DO NOT EDIT.
     * Version: ${slurmVersion}
     */

    #ifndef _CONFIG_H
    #define _CONFIG_H

    /* Package information (from META) */
    #define PACKAGE "slurm"
    #define PACKAGE_NAME "slurm"
    #define PACKAGE_VERSION "${slurmVersion}"
    #define PACKAGE_STRING "slurm ${slurmVersion}"
    #define PACKAGE_BUGREPORT ""
    #define PACKAGE_URL "https://slurm.schedmd.com"

    /* Version numbers (from META) - strings for spank.c compatibility */
    #define SLURM_MAJOR "${slurmMajor}"
    #define SLURM_MINOR "${slurmMinor}"
    #define SLURM_MICRO "${slurmMicro}"
    #define SLURM_VERSION_STRING "${slurmVersion}"
    #define SLURM_VERSION_NUMBER 0x${lib.toHexString versionNumber}

    /* API version (from META) */
    #define SLURM_API_CURRENT ${apiCurrent}
    #define SLURM_API_AGE ${apiAge}
    #define SLURM_API_REVISION ${apiRevision}
    #define SLURM_API_MAJOR ${toString apiMajor}
    #define SLURM_API_VERSION 0x${lib.toHexString apiVersionNumber}

    /* Platform detection */
    #define _GNU_SOURCE 1
    #define HAVE_LINUX 1

    /* Use slurm_ prefix aliases for plugins (Linux) */
    #define USE_ALIAS 1

    /* Standard headers - Linux has all of these */
    #define HAVE_DLFCN_H 1
    #define HAVE_ERRNO_H 1
    #define HAVE_FCNTL_H 1
    #define HAVE_FLOAT_H 1
    #define HAVE_INTTYPES_H 1
    #define HAVE_LIMITS_H 1
    #define HAVE_MEMORY_H 1
    #define HAVE_NETDB_H 1
    #define HAVE_PATHS_H 1
    #define HAVE_PTHREAD_H 1
    #define HAVE_STDINT_H 1
    #define HAVE_STDLIB_H 1
    #define HAVE_STRING_H 1
    #define HAVE_STRINGS_H 1
    #define HAVE_STDBOOL_H 1
    #define HAVE_SYSINT_H 1
    #define HAVE_DIRENT_H 1
    #define HAVE_UNISTD_H 1

    /* System headers */
    #define HAVE_SYS_IPC_H 1
    #define HAVE_SYS_PRCTL_H 1
    #define HAVE_SYS_PTRACE_H 1
    #define HAVE_SYS_SEM_H 1
    #define HAVE_SYS_SHM_H 1
    #define HAVE_SYS_SOCKET_H 1
    #define HAVE_SYS_STAT_H 1
    #define HAVE_SYS_STATFS_H 1
    #define HAVE_SYS_STATVFS_H 1
    #define HAVE_SYS_SYSCTL_H 1
    #define HAVE_SYS_SYSLOG_H 1
    #define HAVE_SYS_TYPES_H 1
    #define HAVE_SYS_VFS_H 1
    #define HAVE_SYS_WAIT_H 1

    /* Linux-specific headers */
    #define HAVE_LINUX_SCHED_H 1
    #define HAVE_PTY_H 1
    #define HAVE_UTMP_H 1

    /* Standard functions */
    #define HAVE_FDATASYNC 1
    #define HAVE_HSTRERROR 1
    #define HAVE_INET_ATON 1
    #define HAVE_STRERROR 1
    #define HAVE_STRERROR_R 1
    #define HAVE_STRNDUP 1
    #define HAVE_STRSIGNAL 1

    /* Linux-specific functions */
    #define HAVE_EPOLL 1
    #define HAVE_GETRANDOM 1
    #define HAVE_GET_CURRENT_DIR_NAME 1
    #define HAVE_MEMFD_CREATE 1
    #define HAVE_PROGRAM_INVOCATION_NAME 1

    /* strlcpy is typically NOT available on Linux (it's a BSD thing) */
    /* #undef HAVE_STRLCPY */

    /* setproctitle is typically NOT available on Linux */
    /* #undef HAVE_SETPROCTITLE */

    /* _progname is typically NOT available on Linux */
    /* #undef HAVE__PROGNAME */

    /* GCC builtins - assume modern GCC/Clang */
    #define HAVE___BUILTIN_BSWAP64 1
    #define HAVE___BUILTIN_CLZLL 1
    #define HAVE___BUILTIN_CTZLL 1
    #define HAVE___BUILTIN_POPCOUNTLL 1

    /* Thread-safe strerror_r returns char* (GNU) vs int (POSIX) */
    #define STRERROR_R_CHAR_P 1

    /* uid_t and gid_t sizes */
    #define SIZEOF_UID_T 4
    #define SIZEOF_GID_T 4

    /* Paths - can be overridden via defines */
    #ifndef SLURM_PREFIX
    #define SLURM_PREFIX "/usr/local"
    #endif

    #ifndef SLURM_SYSCONFDIR
    #define SLURM_SYSCONFDIR "/etc/slurm"
    #endif

    #ifndef SLURM_PLUGINDIR
    #define SLURM_PLUGINDIR "/usr/local/lib/slurm"
    #endif

    #define SLEEP_CMD "/bin/sleep"
    #define SUCMD "/bin/su"

    /* Daemon ports (default values from configure) */
    #define SLURMCTLD_PORT 6817
    #define SLURMCTLD_PORT_COUNT 1
    #define SLURMD_PORT 6818
    #define SLURMDBD_PORT 6819
    #define SLURMRESTD_PORT 6820

    /* Endianness - assume little-endian (x86_64) */
    /* #undef SLURM_BIGENDIAN */

    /* CPU affinity support */
    #define HAVE_SCHED_GETAFFINITY 1
    #define SCHED_GETAFFINITY_THREE_ARGS 1

    /* ptrace arguments (Linux uses 4) */
    #define HAVE_PTRACE 1
    /* #undef HAVE_PTRACE_FIVE_ARGS */

    /* Optional feature flags */
    #define HAVE_LUA 1
    /* #undef HAVE_MUNGE */
    /* #undef HAVE_JSON */
    /* #undef HAVE_JSON_C_INC */
    /* #undef HAVE_HTTP_PARSER */
    /* #undef HAVE_JWT */
    /* #undef HAVE_YAML */
    /* #undef HAVE_HWLOC */
    /* #undef HAVE_LZ4 */
    /* #undef HAVE_PAM */
    /* #undef HAVE_BPF_TOKENS */

    /* Miscellaneous */
    #define HAVE_3ARG_SETPRIORITY 0

    /* Major/minor/makedev from sys/sysmacros.h on modern Linux */
    #define MAJOR_IN_SYSMACROS 1

    #endif /* _CONFIG_H */
  '';

  slurmVersionHContent = ''
    /*
     * slurm_version.h - Auto-generated version info for nixnative builds
     *
     * Generated from META file. DO NOT EDIT.
     * Version: ${slurmVersion}
     */

    #ifndef _SLURM_VERSION_H_
    #define _SLURM_VERSION_H_

    #undef SLURM_VERSION_NUMBER

    /*
     * Define Slurm version number.
     * High-order byte is major version.
     * Middle byte is minor version.
     * Low-order byte is micro version
     */
    #define SLURM_VERSION_NUM(a,b,c) (((a) << 16) + ((b) << 8) + (c))
    #define SLURM_VERSION_MAJOR(a)   (((a) >> 16) & 0xff)
    #define SLURM_VERSION_MINOR(a)   (((a) >>  8) & 0xff)
    #define SLURM_VERSION_MICRO(a)    ((a)        & 0xff)

    #define SLURM_VERSION_NUMBER 0x${lib.toHexString versionNumber}

    #endif /* _SLURM_VERSION_H_ */
  '';

  globalDefaultsCContent = ''
    /*
     * global_defaults.c - Auto-generated for nixnative builds
     *
     * Generated from META file. DO NOT EDIT.
     */
    char *default_plugin_path = "/usr/local/lib/slurm";
    char *default_slurm_config_file = "/etc/slurm/slurm.conf";
  '';

  # ==========================================================================
  # Create generated files in nix store
  # ==========================================================================

  configHDir = pkgs.writeTextDir "config.h" configHContent;
  slurmVersionHDir = pkgs.writeTextDir "slurm/slurm_version.h" slurmVersionHContent;
  globalDefaultsCDir = pkgs.writeTextDir "global_defaults.c" globalDefaultsCContent;

in {
  # Nixnative Tool interface - provides outputs and include dirs
  tool = {
    name = "slurm-autoconf";
    outputs = [
      { rel = "config.h"; path = "${configHDir}/config.h"; }
      { rel = "slurm/slurm_version.h"; path = "${slurmVersionHDir}/slurm/slurm_version.h"; }
      { rel = "global_defaults.c"; path = "${globalDefaultsCDir}/global_defaults.c"; }
    ];
    includeDirs = [
      { path = configHDir; }
      { path = slurmVersionHDir; }
    ];
  };

  # Export version info for other uses
  version = {
    major = slurmMajor;
    minor = slurmMinor;
    micro = slurmMicro;
    string = slurmVersion;
    number = versionNumber;
    api = {
      current = apiCurrent;
      age = apiAge;
      revision = apiRevision;
      major = apiMajor;
      version = apiVersionNumber;
    };
  };
}
