#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
root="/opt/oxdna"

version_output() {
    "$1" -v 2>&1 || true
}

case "$mode" in
    identity)
        for command_name in oxDNA DNAnalysis confGenerator oxDNA_mpi oat python oxdna-generate-sa oxdna-convert-topology mpirun; do
            command -v "$command_name" >/dev/null
        done
        version_output oxDNA | grep -F 'oxDNA v3.7.0' >/dev/null
        version_output DNAnalysis | grep -F 'Configuration analyser for oxDNA v3.7.0' >/dev/null
        (confGenerator -v ignored 2>&1 || true) \
            | grep -F 'Configuration generator for oxDNA v3.7.0' >/dev/null
        version_output oxDNA_mpi | grep -F 'oxDNA v3.7.0' >/dev/null
        python - <<'PY'
import importlib.metadata as md
import matplotlib
import numpy
import oxDNA_analysis_tools
import oxpy
import scipy
import sklearn

assert md.version("oxpy") == "3.7.0"
assert md.version("oxDNA-analysis-tools") == "2.5.0"
assert oxDNA_analysis_tools.__version__ == "2.5.0"
assert numpy.__version__ == "1.26.4"
assert scipy.__version__ == "1.13.1"
assert sklearn.__version__ == "1.5.2"
assert matplotlib.__version__ == "3.9.2"
assert hasattr(oxpy, "OxpyManager")
PY
        oat mean -h 2>&1 | grep -F 'Computes the mean structure of a trajectory file' >/dev/null
        oat config 2>&1 | grep -F 'oxDNA_analysis_tools version: 2.5.0' >/dev/null
        grep -Fx 'commit=b78d23c73c26571eb36def3a2f59f586585461ae' \
            "$root/share/doc/oxdna/source.txt" >/dev/null
        ;;
    simulation)
        tmp="$(mktemp -d /tmp/taf-oxdna-simulation.XXXXXX)"
        trap 'rm -rf "$tmp"' EXIT
        mkdir -p "$tmp/DSDNA8/MD"
        cp "$root/source/test/DNA/DSDNA8/dsdna8.top" "$tmp/DSDNA8/dsdna8.top"
        cp "$root/source/test/DNA/DSDNA8/init.dat" "$tmp/DSDNA8/init.dat"
        cp "$root/source/test/DNA/DSDNA8/MD/quick_input" "$tmp/DSDNA8/MD/input"
        sed -i 's/^steps = .*/steps = 20/' "$tmp/DSDNA8/MD/input"
        sed -i 's/^print_conf_interval = .*/print_conf_interval = 10/' "$tmp/DSDNA8/MD/input"
        sed -i 's/^print_energy_every = .*/print_energy_every = 10/' "$tmp/DSDNA8/MD/input"
        (
            cd "$tmp/DSDNA8/MD"
            oxDNA input >stdout.log 2>stderr.log
            test -s energy.dat
            test -s trajectory.dat
            grep -F 'END OF THE SIMULATION' log.dat >/dev/null
        )
        cp "$root/source/examples/PERSISTENCE_LENGTH/init.top" "$tmp/generator.top"
        cp "$root/source/examples/PERSISTENCE_LENGTH/input_persistences" "$tmp/generator.input"
        sed -i 's/^topology = .*/topology = generator.top/' "$tmp/generator.input"
        sed -i 's/^use_average_seq = .*/use_average_seq = 1/' "$tmp/generator.input"
        (
            cd "$tmp"
            confGenerator generator.input 30 conf_file=generated.dat >generator.stdout 2>generator.stderr
            test -s generated.dat
        )
        printf '%s\n' 'ACGTACGT' > "$tmp/sequences.txt"
        (
            cd "$tmp"
            oxdna-generate-sa 30 sequences.txt >generate-sa.stdout 2>generate-sa.stderr
            test -s generated.dat
            test -s generated.top
            oxdna-convert-topology generated.top generated.dat -p classic_
            test -s classic_generated.top
            test -s classic_generated.dat
        )
        ;;
    mpi)
        tmp="$(mktemp -d /tmp/taf-oxdna-mpi.XXXXXX)"
        trap 'rm -rf "$tmp"' EXIT
        cp -a "$root/source/examples/PARALLEL_TEMPERING/." "$tmp/"
        (
            cd "$tmp"
            sed -i \
                -e 's/^#seed = .*/seed = 12345/' \
                -e 's/^steps = .*/steps = 100/' \
                -e 's/^pt_every = .*/pt_every = 10/' \
                -e 's/^print_conf_interval = .*/print_conf_interval = 50/' \
                -e 's/^print_energy_every = .*/print_energy_every = 10/' \
                inputPT
            mpirun --allow-run-as-root --oversubscribe -np 4 oxDNA_mpi inputPT \
                >stdout.log 2>stderr.log
            for rank in 0 1 2 3; do
                test -s "mpi_${rank}_energy.dat"
                test -s "mpi_${rank}_trajectory.dat"
            done
            grep -F 'END OF THE SIMULATION, everything went OK!' stderr.log >/dev/null
        )
        ;;
    oxpy)
        tmp="$(mktemp -d /tmp/taf-oxdna-oxpy.XXXXXX)"
        trap 'rm -rf "$tmp"' EXIT
        cp "$root/source/test/OXPY/dsdna8.top" "$tmp/dsdna8.top"
        cp "$root/source/test/OXPY/init.dat" "$tmp/init.dat"
        cp "$root/source/test/OXPY/input" "$tmp/input"
        cp "$root/source/test/OXPY/input_analysis" "$tmp/input_analysis"
        cp "$root/source/test/OXPY/trajectory_analysis.dat" "$tmp/trajectory_analysis.dat"
        (
            cd "$tmp"
            DNAnalysis input_analysis >dnanalysis.stdout 2>dnanalysis.stderr
            grep -F 'END OF THE ANALYSIS, everything went OK!' log.dat >/dev/null
            python - <<'PY'
import oxpy

with oxpy.Context():
    simulation_input = oxpy.InputFile()
    simulation_input.init_from_filename("input")
    simulation_input["conf_file"] = "init.dat"
    simulation_input["seed"] = "123456"
    manager = oxpy.OxpyManager(simulation_input)
    manager.run(10)

with oxpy.Context():
    analysis_input = oxpy.InputFile()
    analysis_input.init_from_filename("input_analysis")
    backend = oxpy.analysis.AnalysisBackend(analysis_input)
    count = 0
    while backend.read_next_configuration():
        count += 1
    assert count == 10, count
PY
        )
        ;;
    oat)
        tmp="$(mktemp -d /tmp/taf-oxdna-oat.XXXXXX)"
        trap 'rm -rf "$tmp"' EXIT
        cp "$root/source/analysis/tests/minitraj.dat" "$tmp/minitraj.dat"
        cp "$root/source/analysis/tests/index.txt" "$tmp/index.txt"
        (
            cd "$tmp"
            oat mean -p 1 -o mean.dat -d deviations.json minitraj.dat
            test -s mean.dat
            test -s deviations.json
            oat centroid -p 1 -i index.txt -o centroid.dat mean.dat minitraj.dat
            test -s centroid.dat
            oat distance -c -i minitraj.dat 1 3 5 67
            test -s cluster_data.json
            oat clustering cluster_data.json -e 0.5 -m 2
            test -s cluster_plot.png
        )
        ;;
    structure)
        tmp="$(mktemp -d /tmp/taf-oxdna-structure.XXXXXX)"
        trap 'rm -rf "$tmp"' EXIT
        cp "$root/source/analysis/src/oxDNA_analysis_tools/UTILS/dd12_na.pdb" "$tmp/input.pdb"
        printf '%s\n' 'END' >> "$tmp/input.pdb"
        (
            cd "$tmp"
            oat PDB_oxDNA input.pdb -o converted
            test -s converted.top
            test -s converted.dat
            oat oxDNA_PDB converted.top converted.dat 53 -o roundtrip
            test -s roundtrip.pdb
            grep -F 'ATOM' roundtrip.pdb >/dev/null
        )
        ;;
    *)
        echo "usage: $0 identity|simulation|mpi|oxpy|oat|structure" >&2
        exit 2
        ;;
esac
