ARG PYTHON_IMAGE=python:3.11.18-slim-bookworm@sha256:a83ba18aef0f865b1a4a611c2cf460fe446f2795673bbb9fe43be570439e3b39
FROM ${PYTHON_IMAGE} AS builder

ARG OXDNA_VERSION=3.8.0
ARG OXDNA_COMMIT=f30769e0aad31ce4f40a20ed41f2ac1b8ae13300
ARG OXDNA_SHA256=f7d7052a1e6ac25f00e6e48431cd28116b61bd2b6d723ee17353930d163db98e
ENV DEBIAN_FRONTEND=noninteractive VIRTUAL_ENV=/opt/oxdna/venv
ENV PATH=/opt/oxdna/venv/bin:${PATH}
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1

# Base/source/Python hashes identify the reviewed inputs, not a permanent mirror.
# Debian bookworm/security repositories are live: package revisions may change or
# disappear. PyPI/GitHub files may also become unavailable. Fail closed on hash
# mismatch; re-audit the source and dependencies before refreshing any pin.
COPY docker/requirements.lock /tmp/requirements.lock
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends build-essential ca-certificates \
      cmake curl libopenmpi-dev openmpi-bin libzstd-dev; \
    rm -rf /var/lib/apt/lists/*; \
    python -m venv "${VIRTUAL_ENV}"; \
    python -m pip install --require-hashes --only-binary=:all: -r /tmp/requirements.lock

# Preserve the release directory name: upstream CMake derives its version from
# it. Archive builds truthfully report git revision "none"; the full commit and
# verified archive identity are recorded separately.
# 3.8.0 DHSInteraction.cpp (LEGACY_CODE) omits <cstring> for strncmp.
# Supply that standard declaration via compiler flags, preserving legacy scope.
# The MPI backend still uses strcat on three fields now typed std::string.
# The hash-guarded patch changes only those filename appends, not algorithms.
COPY docker/fix-mpi-filenames.py /tmp/fix-mpi-filenames.py
RUN set -eux; \
    curl -fsSL --retry 4 --connect-timeout 30 --max-time 300 \
      "https://github.com/lorenzo-rovigatti/oxDNA/archive/refs/tags/v${OXDNA_VERSION}.tar.gz" \
      -o /tmp/oxdna.tar.gz; \
    echo "${OXDNA_SHA256}  /tmp/oxdna.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/oxdna.tar.gz -C /tmp; \
    python /tmp/fix-mpi-filenames.py "/tmp/oxDNA-${OXDNA_VERSION}"; \
    cmake -S "/tmp/oxDNA-${OXDNA_VERSION}" -B /tmp/build-cpu \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF -DNATIVE_COMPILATION=OFF -DCMAKE_CXX_FLAGS='-include cstring' \
      -DCUDA=OFF -DMPI=OFF -DPython=ON -DJSON_ENABLED=ON \
      -DLEGACY_CODE=ON -DZSTD_ENABLED=ON; \
    cmake --build /tmp/build-cpu --parallel 2; \
    cmake -S "/tmp/oxDNA-${OXDNA_VERSION}" -B /tmp/build-mpi \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF -DNATIVE_COMPILATION=OFF -DCMAKE_CXX_FLAGS='-include cstring' \
      -DCUDA=OFF -DMPI=ON -DPython=OFF -DJSON_ENABLED=ON \
      -DLEGACY_CODE=ON -DZSTD_ENABLED=ON; \
    cmake --build /tmp/build-mpi --target oxDNA_mpi --parallel 2; \
    make -C "/tmp/oxDNA-${OXDNA_VERSION}/utils/PostSimulationCompression" \
      CFLAGS='-O3 -ffast-math -funroll-loops -std=c11'; \
    python -m pip install --no-build-isolation --no-deps \
      "/tmp/oxDNA-${OXDNA_VERSION}/analysis" /tmp/build-cpu/python; \
    python -m pip check; \
    mkdir -p /opt/oxdna/bin /opt/oxdna/share/doc/oxdna; \
    install -m 0755 /tmp/build-cpu/bin/oxDNA /tmp/build-cpu/bin/DNAnalysis \
      /tmp/build-cpu/bin/confGenerator /tmp/build-mpi/bin/oxDNA_mpi /opt/oxdna/bin/; \
    install -m 0755 "/tmp/oxDNA-${OXDNA_VERSION}/utils/PostSimulationCompression/encode_trj" \
      "/tmp/oxDNA-${OXDNA_VERSION}/utils/PostSimulationCompression/decode_trj" /opt/oxdna/bin/; \
    cp -a "/tmp/oxDNA-${OXDNA_VERSION}" /opt/oxdna/source; \
    cp /tmp/requirements.lock /opt/oxdna/share/doc/oxdna/requirements.lock; \
    cp /tmp/fix-mpi-filenames.py /opt/oxdna/share/doc/oxdna/fix-mpi-filenames.py; \
    printf '%s\n' "version=${OXDNA_VERSION}" "commit=${OXDNA_COMMIT}" \
      "sha256=${OXDNA_SHA256}" 'oat_version=2.6.5' 'source_patches=three MPI histogram filename appends; compiler_compat=-include cstring for legacy DHS' \
      'build=portable CPU double precision; MPI; oxpy; JSON; legacy; ZSTD; no CUDA' \
      > /opt/oxdna/share/doc/oxdna/source.txt; \
    python -m pip list --format=freeze > /opt/oxdna/share/doc/oxdna/python-packages.txt; \
    dpkg-query -W > /opt/oxdna/share/doc/oxdna/build-packages.tsv; \
    strip --strip-unneeded /opt/oxdna/bin/*; \
    find "${VIRTUAL_ENV}" -type f -name '*.so' -exec strip --strip-unneeded '{}' +; \
    python -m pip uninstall -y Cython wheel pip; \
    find "${VIRTUAL_ENV}" -type d \( -name __pycache__ -o -name tests \) -prune -exec rm -rf '{}' +; \
    rm -rf /opt/oxdna/source/analysis/build /opt/oxdna/source/analysis/paper_examples; \
    find /opt/oxdna -type d -exec chmod 0755 '{}' +; \
    find /opt/oxdna -type f -exec chmod a+r,go-w '{}' +

FROM ${PYTHON_IMAGE}
LABEL maintainer="taffish@163.com"
ENV DEBIAN_FRONTEND=noninteractive
# Runtime apt packages have the same live-repository availability boundary as
# the builder. The installed package manifest is retained inside the image.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates libgomp1 libopenmpi3 openmpi-bin libzstd1; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cache
COPY --from=builder /opt/oxdna /opt/oxdna
COPY --chmod=0755 docker/bin/ /usr/local/bin/
COPY --chmod=0755 docker/testdata/oxdna-smoke.sh /opt/oxdna/share/testdata/oxdna-smoke.sh
ENV OXDNA_ROOT=/opt/oxdna OXDNA_SOURCE=/opt/oxdna/source VIRTUAL_ENV=/opt/oxdna/venv
ENV PATH=/opt/oxdna/bin:/opt/oxdna/venv/bin:${PATH}
ENV MPLBACKEND=Agg XDG_CACHE_HOME=/tmp/xdg-cache PYTHONDONTWRITEBYTECODE=1
ENV OXDNA_VERSION=3.8.0 OXDNA_COMMIT=f30769e0aad31ce4f40a20ed41f2ac1b8ae13300 OAT_VERSION=2.6.5
ENV TAFFISH_ENV=TAFFISH TAFFISH_NAME=oxdna
RUN set -eux; \
    ln -s /opt/oxdna/venv/bin/python /usr/local/bin/oxdna-python; \
    dpkg-query -W > /opt/oxdna/share/doc/oxdna/runtime-packages.tsv; \
    /opt/oxdna/share/testdata/oxdna-smoke.sh identity; \
    ldd /opt/oxdna/bin/oxDNA /opt/oxdna/bin/DNAnalysis \
      /opt/oxdna/bin/confGenerator /opt/oxdna/bin/oxDNA_mpi > /tmp/oxdna-ldd.txt; \
    if grep -F 'not found' /tmp/oxdna-ldd.txt; then exit 1; fi; \
    rm -f /tmp/oxdna-ldd.txt
# Build-time checks are limited to identity/imports/linking. Scientific numeric
# assertions, MPI scheduling and plotting run after build on each native backend.
WORKDIR /work
