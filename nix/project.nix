# Slurm nixnative build definitions
{ pkgs, native, lib }:

let
  sources = import ./sources.nix { inherit lib; };

  # Root directory is the parent (slurm repo root)
  root = ./..;

  # Import autoconf tool (generates config.h, slurm_version.h, global_defaults.c)
  autoconf = import ./autoconf.nix { inherit pkgs lib root; };

  # ==========================================================================
  # External Dependencies
  # ==========================================================================

  lz4Lib = native.pkgConfig.makeLibrary {
    name = "lz4";
    packages = [ pkgs.lz4 ];
    modules = [ "liblz4" ];
  };

  # ==========================================================================
  # Project with Shared Defaults
  # ==========================================================================

  project = native.mkProject {
    inherit root;

    defaults = {
      # Common include directories
      includeDirs = [
        "."             # Root for src/common/* includes
        "src"           # For slurm/* headers
      ];

      # Common defines
      defines = [
        "HAVE_CONFIG_H"
        "_GNU_SOURCE"
      ];

      # Common compile flags
      compileFlags = [
        "-fPIC"                      # Required for linking static libs into shared lib
        "-Wno-unused-parameter"      # Slurm has many unused params
        "-Wno-sign-compare"          # Common in Slurm code
      ];

      # C language standard
      languageFlags = { c = [ "-std=gnu11" ]; };

      # Autoconf tool for all targets
      tools = [ autoconf.tool ];
    };
  };

  # ==========================================================================
  # Libraries
  # ==========================================================================

  # libcommon - foundation library
  libcommon = project.staticLib {
    name = "slurm-common";
    sources = sources.libcommon;
    includeDirs = [ "src/common" ];
    linkFlags = [ "-lpthread" "-ldl" "-lm" "-lresolv" ];
    publicIncludeDirs = [ "src" ];
  };

  # libconmgr - connection manager
  libconmgr = project.staticLib {
    name = "slurm-conmgr";
    sources = sources.libconmgr;
    includeDirs = [ "src/conmgr" ];
    libraries = [ libcommon ];
  };

  # libcommon_interfaces - plugin interfaces
  libcommonInterfaces = project.staticLib {
    name = "slurm-interfaces";
    sources = sources.libcommonInterfaces;
    includeDirs = [ "src/interfaces" ];
    libraries = [ libcommon libconmgr ];
  };

  # libslurm - public API shared library
  libslurm = project.sharedLib {
    name = "slurm";
    sources = sources.libslurm;
    includeDirs = [ "src/api" ];
    libraries = [ libcommonInterfaces libconmgr libcommon ];
    linkFlags = [ "-lpthread" "-ldl" "-lm" "-lresolv" ];
  };

  # ==========================================================================
  # CLI Tools
  # ==========================================================================

  cliLibraries = [ libslurm libcommonInterfaces libconmgr libcommon ];
  cliLinkFlags = [ "-lpthread" "-ldl" "-lm" "-lresolv" ];

  # Helper to create binary blob tool for embedding help/usage text
  mkBinaryBlob = dir: files:
    native.tools.binaryBlob.run {
      inherit root;
      inputFiles = map (f: "${dir}/${f}") files;
    };

  sinfo = project.executable {
    name = "sinfo";
    sources = sources.sinfo;
    includeDirs = [ "src/sinfo" ];
    libraries = cliLibraries;
    linkFlags = cliLinkFlags;
    tools = [ (mkBinaryBlob "src/sinfo" [ "help.txt" "usage.txt" ]) ];
  };

  squeue = project.executable {
    name = "squeue";
    sources = sources.squeue;
    includeDirs = [ "src/squeue" ];
    libraries = cliLibraries;
    linkFlags = cliLinkFlags;
    tools = [ (mkBinaryBlob "src/squeue" [ "help.txt" "usage.txt" ]) ];
  };

  scancel = project.executable {
    name = "scancel";
    sources = sources.scancel;
    includeDirs = [ "src/scancel" ];
    libraries = cliLibraries;
    linkFlags = cliLinkFlags;
  };

  sbatch = project.executable {
    name = "sbatch";
    sources = sources.sbatch;
    includeDirs = [ "src/sbatch" ];
    libraries = cliLibraries;
    linkFlags = cliLinkFlags;
  };

  scontrol = project.executable {
    name = "scontrol";
    sources = sources.scontrol;
    includeDirs = [ "src/scontrol" ];
    libraries = cliLibraries;
    linkFlags = cliLinkFlags;
    tools = [ (mkBinaryBlob "src/scontrol" [ "usage.txt" ]) ];
  };

  # ==========================================================================
  # Daemon Libraries
  # ==========================================================================

  libslurmdCommon = project.staticLib {
    name = "slurmd-common";
    sources = sources.libslurmdCommon;
    includeDirs = [ "src/slurmd/common" "src/slurmd" ];
    libraries = [ libcommonInterfaces libconmgr libcommon ];
  };

  libfileBcast = project.staticLib {
    name = "file-bcast";
    sources = sources.libfileBcast;
    includeDirs = [ "src/bcast" ];
    libraries = [ lz4Lib libcommon ];
  };

  libslurmdInterfaces = project.staticLib {
    name = "slurmd-interfaces";
    sources = sources.libslurmdInterfaces;
    includeDirs = [ "src/interfaces" ];
    libraries = [ libcommonInterfaces libconmgr libcommon ];
  };

  libslurmctldInterfaces = project.staticLib {
    name = "slurmctld-interfaces";
    sources = sources.libslurmctldInterfaces;
    includeDirs = [ "src/interfaces" ];
    libraries = [ libcommonInterfaces libconmgr libcommon ];
  };

  libstepmgr = project.staticLib {
    name = "stepmgr";
    sources = sources.libstepmgr;
    includeDirs = [ "src/stepmgr" ];
    libraries = [ libcommonInterfaces libconmgr libcommon ];
  };

  # ==========================================================================
  # Daemons
  # ==========================================================================

  daemonLinkFlags = [ "-lpthread" "-ldl" "-lm" "-lresolv" "-lrt" ];
  daemonLibraries = [ libslurm libcommonInterfaces libconmgr libcommon ];

  slurmd = project.executable {
    name = "slurmd";
    sources = sources.slurmd;
    includeDirs = [ "src/slurmd/slurmd" "src/slurmd" ];
    libraries = [ libfileBcast libslurmdCommon libslurmdInterfaces ] ++ daemonLibraries;
    linkFlags = daemonLinkFlags;
    tools = [ (mkBinaryBlob "src/slurmd/slurmd" [ "usage.txt" ]) ];
  };

  slurmstepd = project.executable {
    name = "slurmstepd";
    sources = sources.slurmstepd;
    includeDirs = [ "src/slurmd/slurmstepd" "src/slurmd" ];
    libraries = [ libstepmgr libfileBcast libslurmdCommon libslurmdInterfaces ] ++ daemonLibraries;
    linkFlags = daemonLinkFlags;
  };

  slurmctld = project.executable {
    name = "slurmctld";
    sources = sources.slurmctld;
    includeDirs = [ "src/slurmctld" ];
    libraries = [ libstepmgr libslurmctldInterfaces ] ++ daemonLibraries;
    linkFlags = daemonLinkFlags;
    tools = [ (mkBinaryBlob "src/slurmctld" [ "usage.txt" ]) ];
  };

  # ==========================================================================
  # Combined package
  # ==========================================================================

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
