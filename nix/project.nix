# Slurm nixnative build definitions
#
# Uses native.project for scoped defaults and direct target references.
{ pkgs, native, lib }:

let
  sources = import ./sources.nix { inherit lib; };
  root = ./..;
  autoconf = import ./autoconf.nix { inherit pkgs lib root; };
  sourceFiles = builtins.mapAttrs (_: patterns:
    native.utils.discoverSources {
      inherit root patterns;
    }
  ) sources;

  # ==========================================================================
  # External Dependencies
  # ==========================================================================

  lz4Lib = native.pkgConfig.makeLibrary {
    name = "lz4";
    packages = [ pkgs.lz4 ];
    modules = [ "liblz4" ];
  };

  # Helper for binary blob embedding
  mkBinaryBlob = dir: files:
    native.tools.binaryBlob.run {
      inherit root;
      inputFiles = map (f: "${dir}/${f}") files;
    };

  # ==========================================================================
  # Project with Shared Defaults
  # ==========================================================================

  slurm = native.project {
    inherit root;
    includeDirs = [ "." "src" ];
    defines = [ "HAVE_CONFIG_H" "_GNU_SOURCE" ];
    compileFlags = [
      "-fPIC"
      "-Wno-unused-parameter"
      "-Wno-sign-compare"
    ];
    languageFlags = { c = [ "-std=gnu11" ]; };
    tools = [ autoconf.tool ];
  };

  # ==========================================================================
  # Core Libraries
  # ==========================================================================

  libcommon = slurm.staticLib {
    name = "libslurm-common";
    sources = sourceFiles.libcommon;
    includeDirs = [ "src/common" ];
    linkFlags = [ "-lpthread" "-ldl" "-lm" "-lresolv" ];
    publicIncludeDirs = [ "src" ];
  };

  libconmgr = slurm.staticLib {
    name = "libslurm-conmgr";
    sources = sourceFiles.libconmgr;
    includeDirs = [ "src/conmgr" ];
    libraries = [ libcommon ];
  };

  libcommonInterfaces = slurm.staticLib {
    name = "libslurm-interfaces";
    sources = sourceFiles.libcommonInterfaces;
    includeDirs = [ "src/interfaces" ];
    libraries = [ libcommon libconmgr ];
  };

  libslurm = slurm.sharedLib {
    name = "libslurm";
    sources = sourceFiles.libslurm;
    includeDirs = [ "src/api" ];
    libraries = [ libcommonInterfaces libconmgr libcommon ];
    linkFlags = [ "-lpthread" "-ldl" "-lm" "-lresolv" ];
  };

  # ==========================================================================
  # CLI Tools
  # ==========================================================================

  # Common settings for all CLI tools
  cliLibraries = [ libslurm libcommonInterfaces libconmgr libcommon ];
  cliLinkFlags = [ "-lpthread" "-ldl" "-lm" "-lresolv" ];

  mkCli = { name, sources, tools ? [], includeDirs ? [] }:
    slurm.executable {
      inherit name sources;
      includeDirs = [ "src/${name}" ] ++ includeDirs;
      libraries = cliLibraries;
      linkFlags = cliLinkFlags;
      inherit tools;
    };

  sinfo = mkCli {
    name = "sinfo";
    sources = sourceFiles.sinfo;
    tools = [ (mkBinaryBlob "src/sinfo" [ "help.txt" "usage.txt" ]) ];
  };

  squeue = mkCli {
    name = "squeue";
    sources = sourceFiles.squeue;
    tools = [ (mkBinaryBlob "src/squeue" [ "help.txt" "usage.txt" ]) ];
  };

  scancel = mkCli {
    name = "scancel";
    sources = sourceFiles.scancel;
  };

  sbatch = mkCli {
    name = "sbatch";
    sources = sourceFiles.sbatch;
  };

  scontrol = mkCli {
    name = "scontrol";
    sources = sourceFiles.scontrol;
    tools = [ (mkBinaryBlob "src/scontrol" [ "usage.txt" ]) ];
  };

  # ==========================================================================
  # Daemon Libraries
  # ==========================================================================

  libslurmdCommon = slurm.staticLib {
    name = "libslurmd-common";
    sources = sourceFiles.libslurmdCommon;
    includeDirs = [ "src/slurmd/common" "src/slurmd" ];
    libraries = [ libcommonInterfaces libconmgr libcommon ];
  };

  libfileBcast = slurm.staticLib {
    name = "libfile-bcast";
    sources = sourceFiles.libfileBcast;
    includeDirs = [ "src/bcast" ];
    libraries = [ lz4Lib libcommon ];
  };

  libslurmdInterfaces = slurm.staticLib {
    name = "libslurmd-interfaces";
    sources = sourceFiles.libslurmdInterfaces;
    includeDirs = [ "src/interfaces" ];
    libraries = [ libcommonInterfaces libconmgr libcommon ];
  };

  libslurmctldInterfaces = slurm.staticLib {
    name = "libslurmctld-interfaces";
    sources = sourceFiles.libslurmctldInterfaces;
    includeDirs = [ "src/interfaces" ];
    libraries = [ libcommonInterfaces libconmgr libcommon ];
  };

  libstepmgr = slurm.staticLib {
    name = "libstepmgr";
    sources = sourceFiles.libstepmgr;
    includeDirs = [ "src/stepmgr" ];
    libraries = [ libcommonInterfaces libconmgr libcommon ];
  };

  # ==========================================================================
  # Daemons
  # ==========================================================================

  daemonLibraries = cliLibraries;
  daemonLinkFlags = [ "-lpthread" "-ldl" "-lm" "-lresolv" "-lrt" ];

  slurmd = slurm.executable {
    name = "slurmd";
    sources = sourceFiles.slurmd;
    includeDirs = [ "src/slurmd/slurmd" "src/slurmd" ];
    libraries = [ libfileBcast libslurmdCommon libslurmdInterfaces ] ++ daemonLibraries;
    linkFlags = daemonLinkFlags;
    tools = [ (mkBinaryBlob "src/slurmd/slurmd" [ "usage.txt" ]) ];
  };

  slurmstepd = slurm.executable {
    name = "slurmstepd";
    sources = sourceFiles.slurmstepd;
    includeDirs = [ "src/slurmd/slurmstepd" "src/slurmd" ];
    libraries = [ libstepmgr libfileBcast libslurmdCommon libslurmdInterfaces ] ++ daemonLibraries;
    linkFlags = daemonLinkFlags;
  };

  slurmctld = slurm.executable {
    name = "slurmctld";
    sources = sourceFiles.slurmctld;
    includeDirs = [ "src/slurmctld" ];
    libraries = [ libstepmgr libslurmctldInterfaces ] ++ daemonLibraries;
    linkFlags = daemonLinkFlags;
    tools = [ (mkBinaryBlob "src/slurmctld" [ "usage.txt" ]) ];
  };

  # ==========================================================================
  # Combined Output
  # ==========================================================================

  all = pkgs.symlinkJoin {
    name = "slurm-all";
    paths = [
      sinfo.target
      squeue.target
      scancel.target
      sbatch.target
      scontrol.target
      slurmd.target
      slurmstepd.target
      slurmctld.target
    ];
  };

in {
  packages = {
    inherit
      libcommon libconmgr libcommonInterfaces libslurm
      libslurmdCommon libfileBcast libslurmdInterfaces libslurmctldInterfaces libstepmgr
      sinfo squeue scancel sbatch scontrol
      slurmd slurmstepd slurmctld
      all;
    default = all;
  };

  devShells.default = native.devShell {
    target = libcommon;
    extraPackages = [ pkgs.gdb ];
  };
}
