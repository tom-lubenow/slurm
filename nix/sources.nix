# Source file patterns for Slurm nixnative build
#
# Uses globs where possible. For directories with files split across
# multiple libraries, we use explicit lists.
{ lib }:

{
  # src/common/ - uses glob, excludes generated global_defaults.c
  # We provide nix/global_defaults.c instead
  libcommon = [ "src/common/*.c" ];

  # src/conmgr/ - all files
  libconmgr = [ "src/conmgr/*.c" ];

  # src/interfaces/ - split across three libraries
  # These need explicit lists because the same directory serves multiple targets
  libcommonInterfaces = [
    "src/interfaces/accounting_storage.c"
    "src/interfaces/acct_gather.c"
    "src/interfaces/acct_gather_energy.c"
    "src/interfaces/acct_gather_filesystem.c"
    "src/interfaces/acct_gather_interconnect.c"
    "src/interfaces/acct_gather_profile.c"
    "src/interfaces/auth.c"
    "src/interfaces/certgen.c"
    "src/interfaces/certmgr.c"
    "src/interfaces/cgroup.c"
    "src/interfaces/cli_filter.c"
    "src/interfaces/conn.c"
    "src/interfaces/cred.c"
    "src/interfaces/data_parser.c"
    "src/interfaces/gpu.c"
    "src/interfaces/gres.c"
    "src/interfaces/hash.c"
    "src/interfaces/http_parser.c"
    "src/interfaces/jobacct_gather.c"
    "src/interfaces/jobcomp.c"
    "src/interfaces/mcs.c"
    "src/interfaces/metrics.c"
    "src/interfaces/mpi.c"
    "src/interfaces/namespace.c"
    "src/interfaces/node_features.c"
    "src/interfaces/prep.c"
    "src/interfaces/priority.c"
    "src/interfaces/select.c"
    "src/interfaces/serializer.c"
    "src/interfaces/site_factor.c"
    "src/interfaces/switch.c"
    "src/interfaces/tls.c"
    "src/interfaces/topology.c"
    "src/interfaces/url_parser.c"
  ];

  # slurmctld-specific interfaces
  libslurmctldInterfaces = [
    "src/interfaces/burst_buffer.c"
    "src/interfaces/job_submit.c"
    "src/interfaces/preempt.c"
    "src/interfaces/sched_plugin.c"
  ];

  # slurmd-specific interfaces
  libslurmdInterfaces = [
    "src/interfaces/proctrack.c"
    "src/interfaces/task.c"
  ];

  # src/api/ - all files for libslurm
  libslurm = [ "src/api/*.c" ];

  # CLI tools - each has its own directory
  sinfo = [ "src/sinfo/*.c" ];
  squeue = [ "src/squeue/*.c" ];
  scancel = [ "src/scancel/*.c" ];
  sbatch = [ "src/sbatch/*.c" ];
  scontrol = [ "src/scontrol/*.c" ];

  # Daemon shared library
  libslurmdCommon = [ "src/slurmd/common/*.c" ];

  # File broadcast library (used by slurmd/slurmstepd)
  libfileBcast = [ "src/bcast/file_bcast.c" ];

  # Additional CLI tools
  sacct = [ "src/sacct/*.c" ];
  sacctmgr = [ "src/sacctmgr/*.c" ];
  sackd = [ "src/sackd/*.c" ];
  salloc = [ "src/salloc/*.c" ];
  sattach = [ "src/sattach/*.c" ];
  sbcast = [ "src/sbcast/*.c" ];
  scrontab = [ "src/scrontab/*.c" ];
  sdiag = [ "src/sdiag/*.c" ];
  sprio = [ "src/sprio/*.c" ];
  sreport = [ "src/sreport/*.c" ];
  srun = [ "src/srun/*.c" ];
  sshare = [ "src/sshare/*.c" ];
  sstat = [ "src/sstat/*.c" ];
  strigger = [ "src/strigger/*.c" ];

  # Additional daemons
  slurmdbd = [ "src/slurmdbd/*.c" ];
  slurmrestd = [
    "src/slurmrestd/http.c"
    "src/slurmrestd/operations.c"
    "src/slurmrestd/slurmrestd.c"
    "src/slurmrestd/openapi.c"
    "src/slurmrestd/rest_auth.c"
  ];

  # Daemons
  slurmd = [ "src/slurmd/slurmd/*.c" ];
  slurmstepd = [ "src/slurmd/slurmstepd/*.c" ];
  slurmctld = [ "src/slurmctld/*.c" ];

  # Step manager library
  libstepmgr = [ "src/stepmgr/*.c" ];
}
