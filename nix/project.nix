# Slurm nixnative build definitions
{ pkgs, native, lib }:

let
  sources = import ./sources.nix { inherit lib; };

  # Root directory is the parent (slurm repo root)
  root = ./..;

  # Import autoconf tool (generates config.h, slurm_version.h, global_defaults.c)
  autoconf = import ./autoconf.nix { inherit pkgs lib root; };
  autoconfTool = autoconf.tool;

  # ==========================================================================
  # Common Build Settings
  # ==========================================================================

  # Common include directories for all Slurm components
  commonIncludeDirs = [
    "."             # Root for src/common/* includes
    "src"           # For slurm/* headers
  ];

  # Common defines for all components
  commonDefines = [
    "HAVE_CONFIG_H"
    "_GNU_SOURCE"
  ];

  # Common compile flags
  commonCompileFlags = [
    "-fPIC"                      # Required for linking static libs into shared lib
    "-Wno-unused-parameter"      # Slurm has many unused params
    "-Wno-sign-compare"          # Common in Slurm code
  ];

  # Common tool list
  commonTools = [ autoconfTool ];

  # External library dependencies
  lz4Lib = native.pkgConfig.makeLibrary {
    name = "lz4";
    packages = [ pkgs.lz4 ];
    modules = [ "liblz4" ];
  };

  # ==========================================================================
  # Libraries
  # ==========================================================================

  # libcommon - foundation library
  libcommon = native.staticLib {
    name = "slurm-common";
    inherit root;
    sources = sources.libcommon;  # global_defaults.c provided by autoconfTool
    includeDirs = commonIncludeDirs ++ [ "src/common" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    ldflags = [ "-lpthread" "-ldl" "-lm" "-lresolv" ];
    publicIncludeDirs = [ "src" ];
    tools = commonTools;
  };

  # libconmgr - connection manager
  libconmgr = native.staticLib {
    name = "slurm-conmgr";
    inherit root;
    sources = sources.libconmgr;
    includeDirs = commonIncludeDirs ++ [ "src/conmgr" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ libcommon ];
    tools = commonTools;
  };

  # libcommon_interfaces - plugin interfaces
  libcommonInterfaces = native.staticLib {
    name = "slurm-interfaces";
    inherit root;
    sources = sources.libcommonInterfaces;
    includeDirs = commonIncludeDirs ++ [ "src/interfaces" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ libcommon libconmgr ];
    tools = commonTools;
  };

  # libslurm - public API shared library
  libslurm = native.sharedLib {
    name = "slurm";
    inherit root;
    sources = sources.libslurm;
    includeDirs = commonIncludeDirs ++ [ "src/api" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ libcommonInterfaces libconmgr libcommon ];
    ldflags = [ "-lpthread" "-ldl" "-lm" "-lresolv" ];
    tools = commonTools;
  };

  # ==========================================================================
  # CLI Tools
  # ==========================================================================

  cliLibraries = [ libslurm libcommonInterfaces libconmgr libcommon ];
  cliLdflags = [ "-lpthread" "-ldl" "-lm" "-lresolv" ];

  # Helper to create binary blob tool for embedding help/usage text
  mkBinaryBlob = dir: files:
    native.tools.binaryBlob.run {
      inherit root;
      inputFiles = map (f: "${dir}/${f}") files;
    };

  # sinfo - has help.txt and usage.txt
  sinfo = native.executable {
    name = "sinfo";
    inherit root;
    sources = sources.sinfo;
    includeDirs = commonIncludeDirs ++ [ "src/sinfo" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = cliLibraries;
    ldflags = cliLdflags;
    tools = commonTools ++ [ (mkBinaryBlob "src/sinfo" [ "help.txt" "usage.txt" ]) ];
  };

  # squeue - has help.txt and usage.txt
  squeue = native.executable {
    name = "squeue";
    inherit root;
    sources = sources.squeue;
    includeDirs = commonIncludeDirs ++ [ "src/squeue" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = cliLibraries;
    ldflags = cliLdflags;
    tools = commonTools ++ [ (mkBinaryBlob "src/squeue" [ "help.txt" "usage.txt" ]) ];
  };

  # scancel - no help/usage txt files
  scancel = native.executable {
    name = "scancel";
    inherit root;
    sources = sources.scancel;
    includeDirs = commonIncludeDirs ++ [ "src/scancel" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = cliLibraries;
    ldflags = cliLdflags;
    tools = commonTools;
  };

  # sbatch - no help/usage txt files
  sbatch = native.executable {
    name = "sbatch";
    inherit root;
    sources = sources.sbatch;
    includeDirs = commonIncludeDirs ++ [ "src/sbatch" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = cliLibraries;
    ldflags = cliLdflags;
    tools = commonTools;
  };

  # scontrol - has usage.txt only
  scontrol = native.executable {
    name = "scontrol";
    inherit root;
    sources = sources.scontrol;
    includeDirs = commonIncludeDirs ++ [ "src/scontrol" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = cliLibraries;
    ldflags = cliLdflags;
    tools = commonTools ++ [ (mkBinaryBlob "src/scontrol" [ "usage.txt" ]) ];
  };

  # ==========================================================================
  # Daemon Libraries
  # ==========================================================================

  # libslurmd_common - shared code for slurmd daemons
  libslurmdCommon = native.staticLib {
    name = "slurmd-common";
    inherit root;
    sources = sources.libslurmdCommon;
    includeDirs = commonIncludeDirs ++ [ "src/slurmd/common" "src/slurmd" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ libcommonInterfaces libconmgr libcommon ];
    tools = commonTools;
  };

  # libfile_bcast - file broadcast library (used by slurmd/slurmstepd)
  libfileBcast = native.staticLib {
    name = "file-bcast";
    inherit root;
    sources = sources.libfileBcast;
    includeDirs = commonIncludeDirs ++ [ "src/bcast" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ lz4Lib libcommon ];
    tools = commonTools;
  };

  # libslurmd_interfaces - slurmd-specific plugin interfaces
  libslurmdInterfaces = native.staticLib {
    name = "slurmd-interfaces";
    inherit root;
    sources = sources.libslurmdInterfaces;
    includeDirs = commonIncludeDirs ++ [ "src/interfaces" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ libcommonInterfaces libconmgr libcommon ];
    tools = commonTools;
  };

  # libslurmctld_interfaces - slurmctld-specific plugin interfaces
  libslurmctldInterfaces = native.staticLib {
    name = "slurmctld-interfaces";
    inherit root;
    sources = sources.libslurmctldInterfaces;
    includeDirs = commonIncludeDirs ++ [ "src/interfaces" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ libcommonInterfaces libconmgr libcommon ];
    tools = commonTools;
  };

  # libstepmgr - step manager library
  libstepmgr = native.staticLib {
    name = "stepmgr";
    inherit root;
    sources = sources.libstepmgr;
    includeDirs = commonIncludeDirs ++ [ "src/stepmgr" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ libcommonInterfaces libconmgr libcommon ];
    tools = commonTools;
  };

  # ==========================================================================
  # Daemons
  # ==========================================================================

  daemonLdflags = [ "-lpthread" "-ldl" "-lm" "-lresolv" "-lrt" ];

  # Common daemon libraries - all daemons link against libslurm
  daemonLibraries = [ libslurm libcommonInterfaces libconmgr libcommon ];

  # slurmd - node daemon (has usage.txt)
  slurmd = native.executable {
    name = "slurmd";
    inherit root;
    sources = sources.slurmd;
    includeDirs = commonIncludeDirs ++ [ "src/slurmd/slurmd" "src/slurmd" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ libfileBcast libslurmdCommon libslurmdInterfaces ] ++ daemonLibraries;
    ldflags = daemonLdflags;
    tools = commonTools ++ [ (mkBinaryBlob "src/slurmd/slurmd" [ "usage.txt" ]) ];
  };

  # slurmstepd - step daemon (no txt files)
  slurmstepd = native.executable {
    name = "slurmstepd";
    inherit root;
    sources = sources.slurmstepd;
    includeDirs = commonIncludeDirs ++ [ "src/slurmd/slurmstepd" "src/slurmd" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ libstepmgr libfileBcast libslurmdCommon libslurmdInterfaces ] ++ daemonLibraries;
    ldflags = daemonLdflags;
    tools = commonTools;
  };

  # slurmctld - controller daemon (has usage.txt)
  slurmctld = native.executable {
    name = "slurmctld";
    inherit root;
    sources = sources.slurmctld;
    includeDirs = commonIncludeDirs ++ [ "src/slurmctld" ];
    defines = commonDefines;
    compileFlags = commonCompileFlags;
    langFlags = { c = [ "-std=gnu11" ]; };
    libraries = [ libstepmgr libslurmctldInterfaces ] ++ daemonLibraries;
    ldflags = daemonLdflags;
    tools = commonTools ++ [ (mkBinaryBlob "src/slurmctld" [ "usage.txt" ]) ];
  };

  # Combined package with all CLI tools and daemons
  all = pkgs.symlinkJoin {
    name = "slurm-all";
    paths = [
      sinfo squeue scancel sbatch scontrol
      slurmd slurmstepd slurmctld
    ];
  };

in {
  packages = {
    inherit libcommon libconmgr libcommonInterfaces libslurm libfileBcast;
    inherit sinfo squeue scancel sbatch scontrol;
    inherit libslurmdCommon libslurmdInterfaces libslurmctldInterfaces libstepmgr;
    inherit slurmd slurmstepd slurmctld;
    inherit all;
    default = all;
  };

  devShell = native.devShell {
    target = libcommon;
    extraPackages = [ pkgs.gdb ];
  };
}
