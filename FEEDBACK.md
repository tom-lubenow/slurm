# Nixnative Feedback - Slurm Port

This document captures papercuts and observations while porting Slurm to nixnative.

## Build Process

### Issue: Silent build failures

When running `nix build .#libcommon`, the command exits with no output even when there may be an error. Need to use `--print-build-logs` but even that can be silent.

**Workaround**: Use `nix build .#libcommon -L` for streaming logs.

### Issue: Result symlink points to .drv file

After `nix build .#libcommon`, the `result` symlink points to a `.drv` file:
```
result -> /nix/store/xxx-slurm-common.drv
```

This is confusing - can't `ls result/` to see what was built. For normal nix builds, `result/` contains the output (bin/, lib/, etc.). With nixnative, there's no obvious way to inspect the built artifact.

**Potential improvement**: Either document this clearly, or provide a helper to materialize/inspect outputs.

### Issue: Hard to tell if rebuild happened

After editing source files, `nix build` completes silently. It's unclear whether:
- The change was picked up and files were recompiled
- Everything was cached and nothing happened

Combined with the `.drv` result symlink, this creates uncertainty about build state.

**Update**: Testing confirmed source changes ARE detected correctly (derivation hash changes, recompilation occurs). The issue is purely UX - silent builds + opaque output make it *feel* like caching is broken.

**Potential improvement**:
- Show a summary of what was rebuilt (e.g., "Rebuilt 3/100 objects")
- Or at minimum, indicate "cached" vs "built" in output

---

## API Observations

### Positive: API is intuitive

The `staticLib`, `sharedLib`, and `executable` functions were easy to use. Defining libraries with `sources`, `includeDirs`, `defines`, `libraries` felt natural.

### Positive: Dependency management works well

Library dependencies via `libraries = [ libcommon libconmgr ]` worked smoothly. The include paths from dependent libraries were automatically available.

### Positive: Tool interface works well for generated files

Slurm's autotools generates several files:
- `config.h` (from configure)
- `slurm/slurm_version.h` (from META file)
- `global_defaults.c` (from template)

We implemented this using nixnative's Tool interface:

```nix
tool = {
  name = "slurm-autoconf";
  headers = [
    { rel = "config.h"; store = "${configHDir}/config.h"; }
    { rel = "slurm/slurm_version.h"; store = "${slurmVersionHDir}/slurm/slurm_version.h"; }
  ];
  sources = [
    { rel = "global_defaults.c"; store = "${globalDefaultsCDir}/global_defaults.c"; }
  ];
  includeDirs = [
    { path = configHDir; }
    { path = slurmVersionHDir; }
  ];
};
```

This works well - the generated files are properly provided to the build without needing to be in the source tree.

**Bug found and fixed:** The `normalizeSourceForNinja` function in `helpers.nix` was using `srcInfo.path` instead of `srcInfo.store` when computing the store base directory for tool-generated sources. Fixed by changing line 95 to use `srcInfo.store`.

### Question: Shared library versioning?

Slurm's libslurm typically has version info (libslurm.so.40.0.0). Is there a way to specify soname/version in `sharedLib`?

### Positive: Glob patterns simplify source definitions

Instead of listing every source file explicitly, nixnative supports glob patterns:

```nix
libcommon = [ "src/common/*.c" ];
libconmgr = [ "src/conmgr/*.c" ];
```

This reduced our `sources.nix` from ~370 lines of explicit file paths to ~90 lines of patterns.

---

## Critical: Untracked Git Files Silently Excluded

**This caused significant confusion during development.**

When the source tree is a git repository, Nix automatically filters the source to only include tracked files. Untracked files are **silently excluded** from the source tree that's copied into the nix store.

**Symptoms:**
- Build fails with "file not found" for files that exist in the working directory
- Appears like a "caching bug" because the file is clearly there
- Running `nix-store --gc` and rebuilding doesn't help
- Very confusing when adding new files

**Example:**
```
$ ls nix/autoconf.nix
nix/autoconf.nix  # File exists
$ nix build .#libcommon
error: getting status of '/nix/store/xxx-source/nix/autoconf.nix': No such file or directory
```

**Solution:** Run `git add` on new files before building:
```
$ git add nix/autoconf.nix
$ nix build .#libcommon  # Now works
```

**Root cause:** This is standard Nix behavior (not nixnative-specific). The `builtins.path` or flake source copying respects `.gitignore` and only includes tracked files. This is usually desirable to avoid including build artifacts, but it's a significant papercut when adding new source files.

**Potential improvement:** Consider adding a warning or hint when a build fails due to a file that exists in the working directory but isn't tracked by git.

---

## Nix Dynamic Derivations Issues

These are likely nix issues rather than nixnative issues, but worth noting.

### Issue: Noisy "Ignoring dynamic derivation" warnings

Every build shows many warnings like:
```
warning: Ignoring dynamic derivation /nix/store/xxx.drv.drv^out while querying missing paths; not yet implemented
```

These don't affect the build but create noise. Possibly a nix limitation with dynamic derivations.

### Issue: "outputs not valid" errors requiring GC

Occasionally encountered:
```
error: some outputs of '/nix/store/xxx.drv.drv' are not valid, so checking is not possible
```

This appeared after a failed build left corrupted state. Required `nix-store --gc` to clean up before rebuilding would work.

**Potential improvement**: Auto-cleanup of invalid outputs, or clearer guidance on recovery.

### Issue: Parallel multi-target builds can fail mysteriously

Running `nix build .#a .#b .#c` sometimes shows cascading failures that don't occur when building targets sequentially. The errors reference dependencies failing but don't clearly indicate the root cause.

---

## C/C++ Build Notes

### Note: -fPIC required for static libs linked into shared libs

When static libraries are linked into a shared library, they must be compiled with `-fPIC`. Without it, you get:
```
ld.lld: error: relocation R_X86_64_PC32 cannot be used against symbol 'foo'; recompile with -fPIC
```

We added `-fPIC` to `commonCompileFlags` for all Slurm components. This is standard C/C++ behavior, not nixnative-specific.

**Potential improvement**: nixnative could automatically add `-fPIC` to static libraries that are dependencies of shared libraries, or at least document this requirement.
