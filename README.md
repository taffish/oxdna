# oxdna

`oxdna` packages oxDNA v3.7.0 for TAFFISH as a portable CPU-first simulation
and analysis runtime.

Package identity:

- name: `oxdna`
- command: `taf-oxdna`
- kind: `tool`
- version: `3.7.0-r1`
- container: `ghcr.io/taffish/oxdna:3.7.0-r1`
- TAFFISH app license: Apache-2.0
- upstream: <https://github.com/lorenzo-rovigatti/oxDNA>
- upstream release: `v3.7.0`

## What This App Packages

The image is built from the checksum-verified upstream `v3.7.0` source archive.
It contains the standalone CPU executables, an MPI build, the `oxpy` Python
bindings, and the oxDNA Analysis Tools (OAT) 2.5.0 from the same release.

The build disables `-march=native`, so the binaries are portable within each
declared architecture. It embeds the upstream release tag and commit in the
runtime version banner because GitHub source archives do not contain `.git`
metadata.

## Scope

This app supports:

- CPU molecular dynamics, Monte Carlo, VMMC, minimization, built-in DNA/RNA,
  Lennard-Jones, patchy-particle, and other upstream core interactions
- `DNAnalysis` trajectory/configuration analysis and `confGenerator` initial
  configuration generation
- the `oxpy` Python API, including simulations and trajectory analysis
- OAT 2.5.0 command-line and Python interfaces, including mean structures,
  deviations, centroids, clustering, PCA, contact maps, alignment, trajectory
  subsets, PDB conversion, and oxView-compatible overlays
- `oxDNA_mpi` with Open MPI for upstream parallel-tempering workflows
- classic/new topology conversion and sequence-based initial generation
- native `linux/amd64` and `linux/arm64`

This app does not include:

- the optional NVIDIA CUDA build or CUDA runtime; use the CPU or MPI path in
  this image
- FFmpeg for OAT 3D animation export; headless static Matplotlib plots work
- a compiler toolchain for building custom `contrib` plugins at runtime
- oxView or other browser-based visualization services

## Container Contents

| Command | Purpose |
| --- | --- |
| `oxDNA` | Default standalone CPU simulator |
| `DNAnalysis` | Analyze configurations and trajectories |
| `confGenerator` | Generate simple initial configurations |
| `oxDNA_mpi` | MPI-enabled upstream executable |
| `python`, `oxdna-python` | Python 3.11 runtime with `oxpy` and OAT |
| `oat` | oxDNA Analysis Tools command dispatcher |
| `oxdna-generate-sa` | Path-preserving launcher for upstream `utils/generate-sa.py` |
| `oxdna-convert-topology` | Launcher for upstream `utils/convert.py` |

Core upstream source, documentation, standard examples, contrib source, and
test fixtures are preserved at `/opt/oxdna/source`. Large OAT paper-example
datasets and generated build artifacts are omitted because they are not
runtime dependencies. Build provenance and installed Python versions are under
`/opt/oxdna/share/doc/oxdna`.

## Usage

Run a simulation through the packaged `oxDNA` command. The explicit command
name is recommended because the input filename is positional:

```sh
taf-oxdna oxDNA input
```

The input file may be followed by upstream `key=value` overrides:

```sh
taf-oxdna oxDNA input steps=1000000 seed=12345
```

Inspect the upstream version:

```sh
taf-oxdna oxDNA -v
```

Upstream `-v` prints the version and exits nonzero by upstream design. The
TAFFISH wrapper version is available through `taf-oxdna --version`.

Analyze an existing trajectory:

```sh
taf-oxdna DNAnalysis analysis_input
```

Generate an initial configuration in a cubic box of side 30:

```sh
taf-oxdna confGenerator generator_input 30
```

Generate files from a sequence list and convert topology formats:

```sh
taf-oxdna oxdna-generate-sa 30 sequences.txt
taf-oxdna oxdna-convert-topology generated.top generated.dat
```

## oxpy and OAT

Run a Python program against the complete `oxpy` API:

```sh
taf-oxdna python analysis.py
```

A minimal import check is:

```sh
taf-oxdna python -c '"import oxpy; print(oxpy.__version__)"'
```

OAT uses `oat <analysis> ...`; the analysis name is an upstream subcommand, so
keep the explicit `oat` command in TAFFISH invocations:

```sh
taf-oxdna oat mean -p 4 -o mean.dat -d deviations.json trajectory.dat
taf-oxdna oat centroid -o centroid.dat mean.dat trajectory.dat
taf-oxdna oat distance -c -i trajectory.dat 1 3 5 67 34 56
taf-oxdna oat clustering cluster_data.json -e 0.5 -m 2
```

Convert between all-atom PDB and coarse-grained oxDNA representations:

```sh
taf-oxdna oat PDB_oxDNA structure.pdb -o structure
taf-oxdna oat oxDNA_PDB structure.top structure.dat 53 -o structure_backmapped
```

List available OAT analyses or inspect one analysis:

```sh
taf-oxdna oat
taf-oxdna oat mean -h
```

The no-argument `oat` listing exits with status 1 by upstream design.

## MPI

The image includes Open MPI and `oxDNA_mpi`. For example:

```sh
TAFFISH_DOCKER_RUN_ARGS="--shm-size=1g" \
  taf-oxdna mpirun --allow-run-as-root --oversubscribe \
  -np 4 oxDNA_mpi inputPT
```

Use `TAFFISH_PODMAN_RUN_ARGS` for the corresponding Podman setting. MPI rank
count, replica inputs, shared-memory size, and scheduler integration remain
workflow-specific. The ordinary `oxDNA` command does not require MPI.

## Command Mode

TAFFISH automatic command mode treats the first non-option argument as an
executable in the image. These are therefore valid:

```sh
taf-oxdna DNAnalysis analysis_input
taf-oxdna oat pca trajectory.dat mean.dat pca.json
taf-oxdna python custom_analysis.py
```

For the same reason, a positional simulation input must use
`taf-oxdna oxDNA input`; `taf-oxdna input` would try to execute a command named
`input` inside the container.

Use `taf-oxdna -- -v` to pass an option-leading argument to the default
`oxDNA` command. Do not use `taf-oxdna mean ...`; `mean` is an OAT analysis,
not a standalone executable.

## Inputs and Outputs

Core programs consume upstream text input files plus topology and
configuration data. Simulations commonly write energy, trajectory,
configuration, checkpoint, and log files named by the input configuration.
`DNAnalysis` writes the configured observable outputs. `confGenerator` and
the sequence utility write topology/configuration pairs.

OAT consumes oxDNA topology/configuration/trajectory files, PDB files, index
lists, force files, and analysis-specific tables. Outputs depend on the OAT
analysis and may include `.dat`, `.json`, `.txt`, `.png`, `.pdb`, and topology
files. All relative paths resolve inside the mounted working directory.

## Runtime Versions

| Component | Version |
| --- | --- |
| oxDNA / oxpy | 3.7.0 |
| OAT (`oxDNA-analysis-tools`) | 2.5.0 |
| Python | 3.11.13 |
| NumPy | 1.26.4 |
| SciPy | 1.13.1 |
| scikit-learn | 1.5.2 |
| Matplotlib | 3.9.2 |

The image contains no external model or reference database and does not need
network access for normal simulations or analysis.

## Platform and Resource Notes

CPU and memory needs scale with nucleotide/particle count, simulation steps,
neighbor-list choice, saved trajectory frequency, and OAT analysis. Long runs
should write into a project directory with enough disk space. OAT uses the
non-interactive `Agg` Matplotlib backend so static plots work in headless
containers.

The CPU binaries use double precision and JSON-enabled external forces and
observables. `-march=native` and link-time optimization are disabled to avoid
host-specific instructions and cross-architecture linker nondeterminism; no
runtime command or scientific model is removed by these build settings.

## Boundaries

CUDA is a separate upstream build mode tied to NVIDIA's compiler and runtime.
Bundling it here would materially increase the image and would not provide a
portable native arm64 contract, so `backend = CUDA` is not supported by this
image. CUDA-only FFS and GPU interaction paths are therefore outside this
release.

The upstream `contrib` plugin source is preserved, but optional plugins are not
precompiled by the upstream default build and this runtime has no compiler.
Use a dedicated development image when modifying or compiling custom plugins.

OAT's 3D cluster animation route invokes external FFmpeg. This image preserves
OAT clustering and static plot output but intentionally omits video encoding.

The packaging applies one path-resolution correction to OAT's bundled DNA/RNA
reference PDB files so `oat oxDNA_PDB` works from any mounted directory. It
does not alter the scientific conversion algorithm.

The two `oxdna-*` utilities use thin launchers rather than direct symbolic
links. `generate-sa.py` locates `src/model.h` relative to its own source path,
while `convert.py` has no executable shebang. The launchers preserve upstream
paths and arguments without changing either script or its generated files.

## Testing

Independent offline smoke tests cover:

- exact core, `oxpy`, OAT, NumPy, SciPy, scikit-learn, and Matplotlib versions
- a tiny CPU DNA simulation plus initial-configuration and topology conversion
- a four-rank MPI parallel-tempering simulation with per-replica outputs
- an `oxpy` simulation and trajectory-reader path
- OAT mean, deviations, centroid, distance clustering, and static plotting
- PDB-to-oxDNA conversion followed by oxDNA-to-PDB backmapping

The image build also checks runtime linkage. Smoke does not replace convergence
testing, force-field validation, long MPI runs, or project-specific scientific
review.

## Documentation, License, and Citation

- manual: <https://lorenzo-rovigatti.github.io/oxDNA/>
- installation: <https://lorenzo-rovigatti.github.io/oxDNA/install.html>
- OAT: <https://lorenzo-rovigatti.github.io/oxDNA/oat/index.html>
- release: <https://github.com/lorenzo-rovigatti/oxDNA/releases/tag/v3.7.0>

The TAFFISH app packaging is Apache-2.0. Upstream oxDNA, oxpy, and OAT retain
their GPL-3.0 terms; bundled third-party components retain their own notices.

For the integrated framework, cite:

> Poppleton E, Matthies M, Mandal D, Romano F, Sulc P, Rovigatti L. oxDNA:
> coarse-grained simulations of nucleic acids made simple. Journal of Open
> Source Software. 2023;8(81):4693. <https://doi.org/10.21105/joss.04693>

OAT/oxView workflows may also require the citations listed in the upstream OAT
manual, including <https://doi.org/10.1093/nar/gkaa417>.
