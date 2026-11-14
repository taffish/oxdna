oxdna 3.8.0-r1

Usage:
  taf-oxdna oxDNA input
  taf-oxdna oxDNA input steps=1000000 seed=12345
  taf-oxdna DNAnalysis analysis_input
  taf-oxdna confGenerator generator_input 30
  Positional input needs explicit "oxDNA": the first non-option word selects
  a command. Run from a writable project folder; relative paths use that folder.

Python and analysis:
  taf-oxdna python analysis.py
  taf-oxdna oat mean -p 4 -o mean.dat -d deviations.json trajectory.dat
  taf-oxdna oat centroid -o centroid.dat mean.dat trajectory.dat
  taf-oxdna oat distance -c -i trajectory.dat 1 3 5 67
  taf-oxdna oat clustering cluster_data.json -e 0.5 -m 2
  taf-oxdna oat PDB_oxDNA structure.pdb -o structure
  taf-oxdna oat oxDNA_PDB structure.top structure.dat 53 -o backmapped
  taf-oxdna oat oxDNA_PDB structure.top structure.dat 53 --format mmcif -o model.cif
  taf-oxdna oat mean -h
  Use "oat <analysis> -h" for each analysis; they are not separate executables.
  Static plots are written to files. Open them with your normal image viewer.

Generation and compression:
  taf-oxdna oxdna-generate-sa 30 sequences.txt
  taf-oxdna oxdna-convert-topology generated.top generated.dat
  taf-oxdna oxDNA input trajectory_compression=true trajectory_file=traj.zst
  taf-oxdna oxdna-decompress-zstd traj.zst trajectory.dat
  taf-oxdna encode_trj trajectory.dat trajectory.vtj 15 6
  taf-oxdna decode_trj trajectory.vtj restored.dat
  OAT reads compressed trajectories directly. VTJ1 rounds coordinates to the
  chosen decimal precision (6 above); keep the original when precision matters.

Local MPI (all ranks inside one container):
  TAFFISH_CONTAINER_BACKEND=docker taf-oxdna mpirun --allow-run-as-root --oversubscribe -np 4 oxDNA_mpi inputPT
  TAFFISH_CONTAINER_BACKEND=podman taf-oxdna mpirun --allow-run-as-root --oversubscribe -np 4 oxDNA_mpi inputPT
  TAFFISH_CONTAINER_BACKEND=apptainer taf-oxdna mpirun --oversubscribe -np 4 oxDNA_mpi inputPT
  Match rank count to your replica inputs. The root flag only permits container
  root; ordinary users can omit it. Multi-node host MPI is not provided.
  If shared memory is insufficient, optionally set Docker/Podman run args to
  "--shm-size=1g". Apptainer uses host IPC/shared-memory limits; ask your admin.

Paths and shared inputs:
  Keep topology, configuration and parameter paths consistent with the input.
  For one argument containing spaces, preserve literal shell quoting through
  the wrapper, e.g. taf-oxdna oxDNA "'input with spaces'".
  Shared inputs outside the project can be mounted read-only at /reference:
  TAFFISH_DOCKER_RUN_ARGS="-v /srv/oxdna/reference:/reference:ro" taf-oxdna oxDNA input
  TAFFISH_CONTAINER_BACKEND=podman TAFFISH_PODMAN_RUN_ARGS="-v /srv/oxdna/reference:/reference:ro" taf-oxdna oxDNA input
  TAFFISH_CONTAINER_BACKEND=apptainer TAFFISH_APPTAINER_RUN_ARGS="--bind /srv/oxdna/reference:/reference:ro" taf-oxdna oxDNA input
  Point the input's topology/conf_file/parameter entries at /reference. OAT
  may write trajectory index sidecars: copy trajectories to a writable folder.

Limits and errors:
  CPU/MPI only: CUDA requests fail; use a separate CUDA build for GPU runs.
  oxDNA3 is preliminary upstream. Choose a model appropriate to your study.
  oxView and Jupyter are separate; load output files there. No GUI server starts.
  FFmpeg animation export and custom compiled contrib plugins are not included.
  Bundled parameters/templates require no download. User files are not fetched.

Help and version:
  taf-oxdna --help
  taf-oxdna --version
  taf-oxdna oxDNA -v
  taf-oxdna -- -v
  Upstream -v prints the version and exits 255 by design. oxDNA has no --help;
  it treats --help as an input filename. No-argument oat lists commands, exits 1.
  Input keys: https://lorenzo-rovigatti.github.io/oxDNA/input.html
  Full scope and examples: https://github.com/taffish/oxdna
