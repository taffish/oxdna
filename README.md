# oxDNA

`oxdna` packages the official oxDNA CPU/MPI simulation framework, oxpy and OAT for TAFFISH.

- Name / command / kind: `oxdna` / `taf-oxdna` / `tool`
- TAFFISH version: `3.8.1-r1`; image: `ghcr.io/taffish/oxdna:3.8.1-r1`
- Native platforms: `linux/amd64`, `linux/arm64`
- Packaging license: Apache-2.0; upstream software retains its separate GPL terms.
- Upstream: [oxDNA](https://github.com/lorenzo-rovigatti/oxDNA), [manual](https://lorenzo-rovigatti.github.io/oxDNA/).

## Scope

Portable CPU double-precision simulations (MD, MC/VMMC, minimization), `DNAnalysis`,
`confGenerator`, local MPI parallel tempering, oxpy 3.8.1 and OAT 2.6.5 are included.
Upstream 3.8.1 fixes VMMC simulations using the original RNA model. The preliminary oxDNA3
and protein ANM models, Zstandard trajectories and PDB/mmCIF conversion remain available.
Model suitability and convergence
remain the researcher's responsibility; a packaging smoke test is not scientific validation.

JSON external-force/observable support, Zstandard and legacy classes are compiled in. Native CPU instruction tuning
and LTO are disabled for portability. CUDA, GPU-only workflows, multi-node host MPI,
FFmpeg animation export, runtime compilation and precompiled contrib plugins are excluded.
The upstream `contrib` sources remain available, including optional ANNaMo workflows;
these are not additional prebuilt command-line services in this package.

## Commands and usage

Install the indexed version with `taf install oxdna 3.8.1-r1` once it is published and indexed.

```sh
taf-oxdna oxDNA input
taf-oxdna oxDNA input steps=1000000 seed=12345
taf-oxdna DNAnalysis analysis_input
taf-oxdna confGenerator generator_input 30
taf-oxdna python analysis.py
taf-oxdna oat mean -p 4 -o mean.dat -d deviations.json trajectory.dat
taf-oxdna oat centroid -o centroid.dat mean.dat trajectory.dat
taf-oxdna oat distance -c -i trajectory.dat 1 3 5 67
taf-oxdna oat clustering cluster_data.json -e 0.5 -m 2
taf-oxdna oat PDB_oxDNA structure.pdb -o structure
taf-oxdna oat oxDNA_PDB structure.top structure.dat 53 --format mmcif -o model.cif
taf-oxdna oat mean -h
```

The default command is `oxDNA`. In command mode, a positional input requires explicit
`oxDNA`; otherwise the first non-option word is interpreted as an executable.
`taf-oxdna --help` shows usage help; `--version` shows wrapper identity.
`taf-oxdna oxDNA -v` (or `taf-oxdna -- -v`) prints upstream identity and intentionally
exits **255**. oxDNA does not implement `--help`; consult the input manual instead.
No-argument `oat` lists its subcommands and exits 1.

Run in a writable project directory. The wrapper mounts the current working directory;
output paths and relative paths in input files are resolved there. Preserve a literal
quoted argument for embedded spaces, for example:

```sh
taf-oxdna oxDNA "'input with spaces'"
taf-oxdna python -c '"import oxpy; print(oxpy.__version__)"'
```

Inputs include topology/configuration pairs, simulation parameter and optional force files,
trajectories, PDB/mmCIF structures and analysis-specific indexes. Outputs include energy,
trajectory, final/checkpoint configuration, logs, JSON overlays, converted structures and
static PNG figures. Some OAT readers write `.pyidx` sidecars beside trajectories; use a
writable copy when analyzing read-only shared files. Retain originals before rerunning into
an existing output directory; upstream tools may overwrite named outputs.

### Preparing a metadynamics sampling folder

Run the bundled upstream script from the working directory containing `run-meta_0/`
and the metadynamics TOML configuration. Supply a new output directory:

```sh
taf-oxdna python /opt/oxdna/source/examples/METADYNAMICS/prepare_sampling.py sampling --config metad_PID.toml
```

The default rescales the final bias by `(1 + dT) / dT`; `--raw_bias` preserves the original
grid instead. Do not reuse an output name with `--force`: the upstream script recursively
replaces that directory. The packaged `toml` reader is pinned at 0.10.2 (MIT); no user install
or network access is needed for this step.

## Generation and compression

```sh
taf-oxdna oxdna-generate-sa 30 sequences.txt
taf-oxdna oxdna-convert-topology generated.top generated.dat
taf-oxdna oxDNA input trajectory_compression=true trajectory_file=traj.zst
taf-oxdna oxdna-decompress-zstd traj.zst trajectory.dat
taf-oxdna encode_trj trajectory.dat trajectory.vtj 15 6
taf-oxdna decode_trj trajectory.vtj restored.dat
```

The first three `oxdna-*` helpers only select the packaged interpreter and upstream script;
they do not rewrite simulation data. OAT can read oxDNA's compressed trajectories directly.
VTJ1 `encode_trj`/`decode_trj` use upstream fixed-point quantization: the last argument above
keeps six decimal places, **not bit-identical text or arbitrary precision**. Keep originals
where this rounding is unacceptable. See the bundled `utils/PostSimulationCompression/README.md`.

## Backends and local MPI

All ordinary commands use the same interface with `TAFFISH_CONTAINER_BACKEND=docker`,
`podman` or `apptainer`. The local MPI launcher runs every rank inside the image:

```sh
TAFFISH_CONTAINER_BACKEND=docker taf-oxdna mpirun --allow-run-as-root --oversubscribe -np 4 oxDNA_mpi inputPT
TAFFISH_CONTAINER_BACKEND=podman taf-oxdna mpirun --allow-run-as-root --oversubscribe -np 4 oxDNA_mpi inputPT
TAFFISH_CONTAINER_BACKEND=apptainer taf-oxdna mpirun --oversubscribe -np 4 oxDNA_mpi inputPT
```

Use inputs with the matching replica/temperature count. The root flag permits container
root only and can be omitted for ordinary users. Larger Docker/Podman jobs may need
`TAFFISH_DOCKER_RUN_ARGS="--shm-size=1g"` or `TAFFISH_PODMAN_RUN_ARGS="--shm-size=1g"`.
Apptainer uses host IPC/shared-memory limits; ask the site administrator if these are too
small. No privileged mode, host MPI ABI integration or cluster scheduler is required or
promised. CPU, memory and disk usage grow with system size, replicas and saved frames.

## Resources and shared use

There is no external model/database download or runtime network requirement for the
supported scope. Force-field constants are built into the official code; PDB nucleotide
templates and example parameter tables are fixed, bundled upstream resources. Both
architectures install them readably for every container user. No per-user preparation,
system-wide downloader, resource discovery or automatic installation is needed.

Custom topology, configuration, force, sequence-dependent parameter and ANM network files
are **user/project inputs**, not a downloadable catalog. An administrator may place such
files in a versioned site directory (directories 0755, files 0644) once; users mount it
read-only, keep output in their own working directory, and explicitly set input file paths:

```sh
TAFFISH_CONTAINER_BACKEND=docker TAFFISH_DOCKER_RUN_ARGS="-v /srv/oxdna/reference:/reference:ro" taf-oxdna oxDNA input
TAFFISH_CONTAINER_BACKEND=podman TAFFISH_PODMAN_RUN_ARGS="-v /srv/oxdna/reference:/reference:ro" taf-oxdna oxDNA input
TAFFISH_CONTAINER_BACKEND=apptainer TAFFISH_APPTAINER_RUN_ARGS="--bind /srv/oxdna/reference:/reference:ro" taf-oxdna oxDNA input
```

For example, set `topology=/reference/system.top` and `conf_file=/reference/initial.dat`
in `input`; pass any project parameter path through the upstream model's input keys.
No helper changes ownership, downloads data, deletes libraries, or traverses recovery
directories. User-supplied data retain their own terms; bundled templates retain upstream
terms. Symlinks must resolve within a mounted readable location; unavailable inputs fail.

## Visualization boundary

OAT's Matplotlib **Agg** plots are saved as local files. View them outside the container.
[oxView](https://sulcgroup.github.io/oxdna-viewer/) is the official independent browser
viewer/editor; it consumes topology/configuration, trajectory and overlay files.
OAT's notebook helper embeds the external oxView page in an iframe; it is not a local
server and needs a separately installed notebook environment and network access to that
viewer. Jupyter, oxView, tacoxDNA and Adenita are not bundled services. No GUI port,
authentication or service lifecycle is added to this CLI package.

## Build provenance and reproducibility

Official [v3.8.1 release](https://github.com/lorenzo-rovigatti/oxDNA/releases/tag/v3.8.1),
commit `130eee4cca4b96ac23f6fa11a9eab44ecdf8fa4a`, archive SHA256
`8f5ea2a55d2413e4b2ed7afb6100e209a9d3c52810417804fefedcb97db6a222`.
Scientific algorithms are unchanged. Two build compatibility fixes are disclosed:
`-include cstring` supplies the standard `strncmp` declaration missing from the
legacy DHS class; `docker/fix-mpi-filenames.py` replaces three obsolete `strcat`
calls with `std::string` appends in the MPI backend. The latter only appends replica
numbers to histogram filenames and refuses an unexpected upstream file hash.
The old release-metadata and PDB-path
patches are removed: upstream now supports archive version detection and package-relative
templates. An archive build honestly reports revision `none`; the full source identity is
stored in `/opt/oxdna/share/doc/oxdna/source.txt`.

The digest-pinned base contains Python 3.11.18. `docker/requirements.lock` pins and hashes
all Python wheel inputs (NumPy 1.26.4, SciPy 1.13.1, scikit-learn 1.8.0, Matplotlib 3.11.2,
Pillow 13.0.0 and Zstandard 0.25.0 included). Native build dependencies and runtime package
manifests are recorded in the image. Live Debian repositories can change or remove package
revisions; GitHub/PyPI availability is also external. Hashes detect changed content; they do
not guarantee future downloads or bit-for-bit rebuilds. Do not blindly replace hashes after
a failed fetch. Dockerfile build context is the app root, `-f docker/Dockerfile .`.

Installed source, documentation, test examples and licenses are in `/opt/oxdna/source`;
large `analysis/paper_examples` and generated build files are omitted. Executables live in
`/opt/oxdna/bin`, Python packages in `/opt/oxdna/venv`; `oxdna-python` selects that interpreter.

## Troubleshooting

- A filename is treated as a command: insert explicit `oxDNA`.
- Spaces split an argument: retain literal shell quoting as shown above.
- `-v` returns 255: this is upstream version behavior, not a failed installation.
- A read-only trajectory cannot be indexed: copy it to your writable project folder.
- MPI rank/IPC errors: check replica count, available CPUs and shared memory; this is not a multi-node MPI image.
- CUDA backend requested: use an independently built upstream CUDA image instead.
- A model/file is absent: correct the explicit mounted path; there is no implicit download fallback.

## Validation

The 3.8.1-r1 images were built natively for linux/amd64 and linux/arm64. The
generated TAFFISH wrapper was exercised with Docker and Podman on both platforms,
and with Apptainer on native x86-64 Linux. Each backend ran the small CPU and
four-rank MPI workflows, the original RNA/VMMC regression, both sampling-bias
modes, read-only shared inputs and OAT plotting without network access.
MPI startup is tested at runtime, not required of the Dockerfile builder.

Uncompressed Docker image sizes: 481.8 MB (amd64) and 495.8 MB (arm64);
the previous 3.8.0-r1 measurements were 481.7 MB and 496.5 MB respectively.
These figures are not registry download sizes. The tested amd64 SIF was 166.7 MB.

These checks do not establish production scaling, convergence, force-field accuracy or
biological validity. No publication, remote CI success or Index acceptance is implied.

## License and citation

TAFFISH packaging: [Apache-2.0](LICENSE). Upstream oxDNA/oxpy declare GPL-3.0-or-later;
OAT uses GPLv3. Upstream license files, bundled third-party notices and Debian copyright
files remain in the image; the packaging license does not relicense those components.

Poppleton E et al. *oxDNA: coarse-grained simulations of nucleic acids made simple*.
JOSS 8(81):4693 (2023), [doi:10.21105/joss.04693](https://doi.org/10.21105/joss.04693).
Also cite the force-field and OAT methods actually used, following the upstream manual.
