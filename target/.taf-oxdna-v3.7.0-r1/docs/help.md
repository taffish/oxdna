oxdna 3.7.0-r1

Purpose:
  Run the oxDNA 3.7.0 coarse-grained DNA/RNA simulation framework with its
  CPU executables, MPI build, oxpy Python API, and OAT 2.5.0 analysis tools.

Usage:
  taf-oxdna oxDNA input
  taf-oxdna oxDNA input steps=1000000 seed=12345
  taf-oxdna DNAnalysis analysis_input
  taf-oxdna confGenerator generator_input 30

Packaged commands:
  oxDNA                    Default CPU simulator.
  DNAnalysis               Analyze configurations and trajectories.
  confGenerator            Generate a simple initial configuration.
  oxDNA_mpi                MPI-enabled upstream executable.
  mpirun                   Launch a local MPI workflow in the container.
  oat                      oxDNA Analysis Tools dispatcher.
  python, oxdna-python     Python 3.11 runtime with oxpy and OAT.

Python and OAT:
  taf-oxdna python analysis.py
  taf-oxdna oat mean -p 4 -o mean.dat -d devs.json trajectory.dat
  taf-oxdna oat centroid -o centroid.dat mean.dat trajectory.dat
  taf-oxdna oat distance -c -i trajectory.dat 1 3 5 67 34 56
  taf-oxdna oat clustering cluster_data.json -e 0.5 -m 2
  taf-oxdna oat PDB_oxDNA structure.pdb -o structure
  taf-oxdna oat oxDNA_PDB structure.top structure.dat 53 -o backmapped
  Analyses are oat subcommands, not standalone executables. Run "taf-oxdna
  oat <analysis> -h" for options. The no-argument oat listing exits with 1.

Helpers:
  taf-oxdna oxdna-generate-sa 30 sequences.txt
  taf-oxdna oxdna-convert-topology generated.top generated.dat
  These launch upstream sequence generation and classic/new topology conversion.

MPI example:
  TAFFISH_DOCKER_RUN_ARGS="--shm-size=1g" \
    taf-oxdna mpirun --allow-run-as-root --oversubscribe \
    -np 4 oxDNA_mpi inputPT
  Use TAFFISH_PODMAN_RUN_ARGS for Podman. Rank count, replica inputs, shared
  memory, and cluster scheduler integration are workflow-specific.

Inputs and outputs:
  Core runs use oxDNA input, topology, and configuration files and commonly
  write energy, trajectory, configuration, checkpoint, and log files. OAT
  accepts trajectories, topology/configuration pairs, PDB files, indexes, and
  analysis-specific tables. Relative paths use the mounted working directory.

Packaged versions:
  oxDNA / oxpy / OAT       3.7.0 / 3.7.0 / 2.5.0
  Python / NumPy / SciPy   3.11.13 / 1.26.4 / 1.13.1
  scikit-learn             1.5.2
  Matplotlib               3.9.2, headless Agg backend

Platform and resources:
  Native linux/amd64 and linux/arm64 are supported. CPU and memory use scale
  with system size, simulation length, trajectory frequency, and analysis.
  No external database, model download, or network access is required.

Boundaries:
  This portable image is CPU/MPI only; the optional NVIDIA CUDA build and
  CUDA-only workflows are not included. Static OAT plots work, but FFmpeg and
  3D animation export are not bundled. Upstream contrib source is preserved,
  but custom plugins are not precompiled and no compiler is in the runtime.
  oxView and other browser visualization services are separate tools.
  Source, docs, examples, tests, and provenance are under /opt/oxdna.

Upstream behavior:
  taf-oxdna oxDNA -v               Show the upstream runtime version.
  taf-oxdna -- -v                  Pass -v to the default oxDNA command.
  Positional input needs explicit "oxDNA" because command mode treats the
  first non-option argument as a packaged executable.
  oxDNA has no standard --help; it treats --help as an input filename. Use
  the upstream manual for input keys. Upstream -v prints and exits nonzero.

Documentation:
  https://github.com/taffish/oxdna
  https://lorenzo-rovigatti.github.io/oxDNA/
  https://lorenzo-rovigatti.github.io/oxDNA/oat/index.html

Wrapper options:
  --help / --version               Show TAFFISH help or wrapper version.
  --compile                        Print the generated wrapper shell code.
  -- -v                            Pass an option-leading argument to oxDNA.

Scientific note:
  Smoke tests cover tiny deterministic execution paths, not convergence,
  force-field suitability, production MPI scaling, or biological validation.
