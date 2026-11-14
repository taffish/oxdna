# oxDNA

`oxdna` packages the official oxDNA CPU/MPI simulation framework, oxpy and OAT for TAFFISH.

- Name / command / kind: `oxdna` / `taf-oxdna` / `tool`
- TAFFISH version: `3.8.0-r1`; image: `ghcr.io/taffish/oxdna:3.8.0-r1`
- Native platforms: `linux/amd64`, `linux/arm64`
- Packaging license: Apache-2.0; upstream software retains its separate GPL terms.
- Upstream: [oxDNA](https://github.com/lorenzo-rovigatti/oxDNA), [manual](https://lorenzo-rovigatti.github.io/oxDNA/).

## Scope

Portable CPU double-precision simulations (MD, MC/VMMC, minimization), `DNAnalysis`,
`confGenerator`, local MPI parallel tempering, oxpy 3.8.0 and OAT 2.6.5 are included.
The official 3.8.0 release adds preliminary oxDNA3 and protein ANM models, Zstandard
trajectory support and updated PDB/mmCIF conversion. Model suitability and convergence
remain the researcher's responsibility; a packaging smoke test is not scientific validation.

JSON external-force/observable support, Zstandard and legacy classes are compiled in. Native CPU instruction tuning
and LTO are disabled for portability. CUDA, GPU-only workflows, multi-node host MPI,
FFmpeg animation export, runtime compilation and precompiled contrib plugins are excluded.
The upstream `contrib` sources remain available, including optional ANNaMo workflows;
these are not additional prebuilt command-line services in this package.

## Commands and usage

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
TAFFISH_DOCKER_RUN_ARGS="-v /srv/oxdna/reference:/reference:ro" taf-oxdna oxDNA input
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

Official [v3.8.0 release](https://github.com/lorenzo-rovigatti/oxDNA/releases/tag/v3.8.0),
commit `f30769e0aad31ce4f40a20ed41f2ac1b8ae13300`, archive SHA256
`f7d7052a1e6ac25f00e6e48431cd28116b61bd2b6d723ee17353930d163db98e`.
Scientific algorithms are unchanged. Two build compatibility fixes are disclosed:
`-include cstring` supplies the standard `strncmp` declaration missing from 3.8.0's
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

The 3.8.0-r1 candidate was tested on native amd64 (Docker, Podman and Apptainer)
and native arm64 (Docker and Podman). The checks include every exact manifest probe,
non-root/read-only execution, real frozen wrappers, tiny CPU/MPI/oxpy workflows,
MPI histogram output/reload, OAT plots, PDB/mmCIF, DNA3/ANM and compressed trajectories.
Shared read-only inputs, valid/broken input symlinks, failure exit codes and diagnostic
retention were checked. Apptainer used a read-only SIF converted from the same amd64 image.
All 1,482 retained original source files match their pinned identities, except the three
disclosed MPI filename append lines, whose resulting hash is checked separately.

Uncompressed local image sizes: amd64 approximately 481.7 MB; arm64 496.5 MB.
The old 3.7.0 image was not available locally for a like-for-like size comparison.
Build tools/download caches stay outside the final multi-stage image; runtime dependencies,
readable templates, licenses, source and useful examples are retained.

These checks do not establish production scaling, convergence, force-field accuracy or
biological validity. No publication, remote CI success or Index acceptance is implied.

## License and citation

TAFFISH packaging: [Apache-2.0](LICENSE). Upstream oxDNA/oxpy declare GPL-3.0-or-later;
OAT uses GPLv3. Upstream license files, bundled third-party notices and Debian copyright
files remain in the image; the packaging license does not relicense those components.

Poppleton E et al. *oxDNA: coarse-grained simulations of nucleic acids made simple*.
JOSS 8(81):4693 (2023), [doi:10.21105/joss.04693](https://doi.org/10.21105/joss.04693).
Also cite the force-field and OAT methods actually used, following the upstream manual.
