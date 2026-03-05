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

  sacct = mkCli {
    name = "sacct";
    sources = sourceFiles.sacct;
    tools = [ (mkBinaryBlob "src/sacct" [ "help.txt" ]) ];
  };

  sacctmgr = mkCli {
    name = "sacctmgr";
    sources = sourceFiles.sacctmgr;
    tools = [ (mkBinaryBlob "src/sacctmgr" [ "usage.txt" ]) ];
  };

  sackd = mkCli {
    name = "sackd";
    sources = sourceFiles.sackd;
    tools = [ (mkBinaryBlob "src/sackd" [ "usage.txt" ]) ];
  };

  salloc = mkCli {
    name = "salloc";
    sources = sourceFiles.salloc;
  };

  sattach = mkCli {
    name = "sattach";
    sources = sourceFiles.sattach;
  };

  sdiag = mkCli {
    name = "sdiag";
    sources = sourceFiles.sdiag;
  };

  sprio = mkCli {
    name = "sprio";
    sources = sourceFiles.sprio;
    tools = [ (mkBinaryBlob "src/sprio" [ "help.txt" "usage.txt" ]) ];
  };

  sreport = mkCli {
    name = "sreport";
    sources = sourceFiles.sreport;
  };

  sshare = mkCli {
    name = "sshare";
    sources = sourceFiles.sshare;
  };

  sstat = mkCli {
    name = "sstat";
    sources = sourceFiles.sstat;
  };

  strigger = mkCli {
    name = "strigger";
    sources = sourceFiles.strigger;
  };

  scrontab = mkCli {
    name = "scrontab";
    sources = sourceFiles.scrontab;
    tools = [ (mkBinaryBlob "src/scrontab" [ "default_crontab.txt" "usage.txt" ]) ];
  };

  # sbcast and srun need libfileBcast
  sbcast = slurm.executable {
    name = "sbcast";
    sources = sourceFiles.sbcast;
    includeDirs = [ "src/sbcast" ];
    libraries = [ libfileBcast ] ++ cliLibraries;
    linkFlags = cliLinkFlags;
  };

  srun = slurm.executable {
    name = "srun";
    sources = sourceFiles.srun;
    includeDirs = [ "src/srun" ];
    libraries = [ libfileBcast ] ++ cliLibraries;
    linkFlags = cliLinkFlags;
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

  slurmdbd = slurm.executable {
    name = "slurmdbd";
    sources = sourceFiles.slurmdbd;
    includeDirs = [ "src/slurmdbd" ];
    libraries = daemonLibraries;
    linkFlags = daemonLinkFlags;
  };

  slurmrestd = slurm.executable {
    name = "slurmrestd";
    sources = sourceFiles.slurmrestd;
    includeDirs = [ "src/slurmrestd" ];
    libraries = daemonLibraries;
    linkFlags = daemonLinkFlags;
    tools = [ (mkBinaryBlob "src/slurmrestd" [ "usage.txt" ]) ];
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
      sacct.target
      sacctmgr.target
      sackd.target
      salloc.target
      sattach.target
      sbcast.target
      scrontab.target
      sdiag.target
      sprio.target
      sreport.target
      srun.target
      sshare.target
      sstat.target
      strigger.target
      slurmd.target
      slurmstepd.target
      slurmctld.target
      slurmdbd.target
      slurmrestd.target
    ];
  };

in {
  packages = {
    inherit
      libcommon libconmgr libcommonInterfaces libslurm
      libslurmdCommon libfileBcast libslurmdInterfaces libslurmctldInterfaces libstepmgr
      sinfo squeue scancel sbatch scontrol
      sacct sacctmgr sackd salloc sattach sbcast scrontab sdiag sprio sreport srun sshare sstat strigger
      slurmd slurmstepd slurmctld slurmdbd slurmrestd
      all;
    default = all;
  };

  devShells.default = native.devShell {
    target = libcommon;
    extraPackages = [ pkgs.gdb ];
  };
}
