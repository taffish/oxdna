#!/usr/bin/env bash
set -Eeuo pipefail

mode="${1:-}"
root="/opt/oxdna"
report_failure() {
    local status="$1" failed_command="$2"
    trap - ERR
    printf 'oxdna-smoke stage=%s exit=%s command=%s\n' "$mode" "$status" "$failed_command" >&2
    if [[ -n "${tmp:-}" && -d "$tmp" ]]; then
        while IFS= read -r -d '' log; do
            printf '\n--- %s ---\n' "${log#"$tmp"/}" >&2
            tail -n 30 "$log" >&2 || true
        done < <(find "$tmp" -type f \( -name '*.log' -o -name '*.stdout' -o -name '*.stderr' \) -print0)
    fi
    exit "$status"
}
trap 'report_failure "$?" "$BASH_COMMAND"' ERR

version_output() {
    local output status=0
    output="$("$@" -v 2>&1)" || status=$?
    # Upstream print_version() deliberately calls exit(-1), i.e. 255.
    test "$status" -eq 255 || { printf '%s\n' "$output" >&2; return 1; }
    printf '%s\n' "$output"
}

case "$mode" in
    identity)
        for command_name in oxDNA DNAnalysis confGenerator oxDNA_mpi oat python oxdna-generate-sa oxdna-convert-topology mpirun; do
            command -v "$command_name" >/dev/null
        done
        version_output oxDNA | grep -E '^oxDNA v3\.8\.0 by ' >/dev/null
        version_output DNAnalysis | grep -E '^Configuration analyser for oxDNA v3\.8\.0' >/dev/null
        status=0
        output="$(confGenerator -v ignored 2>&1)" || status=$?
        test "$status" -eq 255
        printf '%s\n' "$output" | grep -E '^Configuration generator for oxDNA v3\.8\.0' >/dev/null
        version_output oxDNA_mpi | grep -E '^oxDNA v3\.8\.0 by ' >/dev/null
        python - <<'PY'
import importlib.metadata as md
import matplotlib
import numpy
import oxDNA_analysis_tools
import oxpy
import scipy
import sklearn

assert md.version("oxpy") == "3.8.0"
assert md.version("oxDNA-analysis-tools") == "2.6.5"
assert oxDNA_analysis_tools.__version__ == "2.6.5"
assert numpy.__version__ == "1.26.4"
assert scipy.__version__ == "1.13.1"
assert sklearn.__version__ == "1.8.0"
assert matplotlib.__version__ == "3.11.2"
import zstandard
assert zstandard.__version__ == "0.25.0"
assert hasattr(oxpy, "OxpyManager")
PY
        oat mean -h 2>&1 | grep -F 'Computes the mean structure of a trajectory file' >/dev/null
        oat config 2>&1 | grep -F 'oxDNA_analysis_tools version: 2.6.5' >/dev/null
        grep -Fx 'commit=f30769e0aad31ce4f40a20ed41f2ac1b8ae13300' \
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
            # Exercise the three compatibility-patched filename append branches.
            mkdir umbrella
            cp "$root/source/examples/VMMC_MELTING/"{input,init.dat,prova.top,op.txt,wfile.txt,seq.txt} umbrella/
            cd umbrella
            for rank in 0 1 2 3; do cp init.dat "init.dat${rank}"; done
            mpirun --allow-run-as-root --oversubscribe -np 4 oxDNA_mpi input \
                sim_type=PT_VMMC pt_temp_list=325K,335K,345K,355K pt_every=10 \
                pt_common_weights=1 steps=20 print_conf_interval=10 print_energy_every=10 \
                >umbrella.stdout 2>umbrella.stderr
            for rank in 0 1 2 3; do
                test -s "last_hist.dat${rank}"
                test -s "traj_hist.dat${rank}"
            done
            cp last_hist.dat0 restart_hist.dat
            mpirun --allow-run-as-root --oversubscribe -np 4 oxDNA_mpi input \
                sim_type=PT_VMMC pt_temp_list=325K,335K,345K,355K pt_every=10 \
                pt_common_weights=1 steps=20 print_conf_interval=10 print_energy_every=10 \
                init_hist_file=restart_hist.dat >reload.stdout 2>reload.stderr
            grep -F 'END OF THE SIMULATION, everything went OK!' reload.stderr >/dev/null
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
        cp "$root/source/analysis/tests/resources/minitraj.dat" "$tmp/minitraj.dat"
        printf '0 1 2 3\n' > "$tmp/index.txt"
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
        cp "$root/source/test/OXPY/dsdna8.top" "$tmp/input.top"
        cp "$root/source/test/OXPY/init.dat" "$tmp/input.dat"
        (
            cd "$tmp"
            oat oxDNA_PDB input.top input.dat 53 -o input
            test -s input.pdb
            oat PDB_oxDNA input.pdb -o converted
            test -s converted.top
            test -s converted.dat
            oat oxDNA_PDB converted.top converted.dat 53 -o roundtrip
            test -s roundtrip.pdb
            grep -F 'ATOM' roundtrip.pdb >/dev/null
            oat oxDNA_PDB converted.top converted.dat 53 --format mmcif -o roundtrip.cif
            test -s roundtrip.cif
        )
        ;;
    compression)
        tmp="$(mktemp -d /tmp/taf-oxdna-compression.XXXXXX)"
        trap 'rm -rf "$tmp"' EXIT
        cp "$root/source/test/OXPY/"{dsdna8.top,init.dat,input} "$tmp/"
        (
            cd "$tmp"
            oxDNA input conf_file=init.dat steps=20 seed=12345 print_conf_interval=10 trajectory_file=traj.zst \
                trajectory_compression=true >stdout.log 2>stderr.log
            oxdna-decompress-zstd traj.zst decoded.dat
            test -s decoded.dat
            grep -q '^t = ' decoded.dat
            oat mean -p 1 -o mean.dat traj.zst
            test -s mean.dat
            encode_trj decoded.dat traj.vtj 15 6
            decode_trj traj.vtj restored.dat
            python - <<'PY'
from pathlib import Path
import numpy as np
# Upstream VTJ1 adds a blank separator after each decoded frame.
a=[x for x in Path('decoded.dat').read_text().splitlines() if x.strip()]
b=[x for x in Path('restored.dat').read_text().splitlines() if x.strip()]
assert len(a)==len(b)>0
for x,y in zip(a,b):
    assert ('=' in x)==('=' in y)
    if '=' in x:
        assert x.split('=')[0].strip()==y.split('=')[0].strip()
    x=x.split('=')[-1]; y=y.split('=')[-1]
    original=np.fromstring(x,sep=' '); restored=np.fromstring(y,sep=' ')
    assert original.shape==restored.shape and original.size>0
    assert np.isfinite(restored).all()
    assert np.allclose(original,restored,atol=1.1e-6,rtol=0)
PY
        )
        ;;
    models)
        tmp="$(mktemp -d /tmp/taf-oxdna-models.XXXXXX)"
        trap 'rm -rf "$tmp"' EXIT
        cp "$root/source/test/OXPY/"{dsdna8.top,init.dat,input} "$tmp/"
        (
            cd "$tmp"
            oxDNA input conf_file=init.dat lastconf_file=last_conf.dat interaction_type=DNA3 use_average_seq=1 \
                salt_concentration=0.5 steps=2 seed=12345 log_file=dna3.log \
                >dna3.stdout 2>dna3.stderr
            test -s last_conf.dat
            mkdir protein
            cp "$root/source/examples/DNANM/KDPG/"{input_dnanm,generated.top,s1.dat,kdpg_anm.par} protein/
            cd protein
            oxDNA input_dnanm steps=2 print_energy_every=1 print_conf_interval=1 \
                >stdout.log 2>stderr.log
            test -s energy.dat
            test -s trajectory.dat
        )
        ;;
    *)
        echo "usage: $0 identity|simulation|mpi|oxpy|oat|structure|compression|models" >&2
        exit 2
        ;;
esac
