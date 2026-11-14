"""Fix three obsolete C-string appends in the pinned 3.8.0 MPI backend."""
import hashlib
import pathlib
import sys

path = pathlib.Path(sys.argv[1]) / "src/Backends/PT_VMMC_CPUBackend.cpp"
original = path.read_bytes()
expected = "71d963f25b5695cdf3bfc1346946a650fd24199f3698c11cf8069181a8fddc38"
if hashlib.sha256(original).hexdigest() != expected:
    raise SystemExit("MPI compatibility patch: unexpected upstream file identity")
updated = original
for name in ("_init_hist_file", "_last_hist_file", "_traj_hist_file"):
    old = f"strcat({name}, extra);".encode()
    new = f"{name} += extra;".encode()
    if updated.count(old) != 1:
        raise SystemExit(f"MPI compatibility patch: unexpected occurrence count for {name}")
    updated = updated.replace(old, new)
path.write_bytes(updated)
print("MPI filename compatibility patch:", expected, "->", hashlib.sha256(updated).hexdigest())
