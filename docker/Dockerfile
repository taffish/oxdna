ARG PYTHON_IMAGE=python:3.11.13-slim-bookworm

FROM ${PYTHON_IMAGE} AS builder

ARG OXDNA_VERSION=3.7.0
ARG OXDNA_TAG=v3.7.0
ARG OXDNA_COMMIT=b78d23c73c26571eb36def3a2f59f586585461ae
ARG OXDNA_SHA256=74d6675a544e9c7a52ff692e698744f190a508c65d62dd08c065ff887414a787
ARG OAT_VERSION=2.5.0
ARG NUMPY_VERSION=1.26.4
ARG SCIPY_VERSION=1.13.1
ARG SCIKIT_LEARN_VERSION=1.5.2
ARG MATPLOTLIB_VERSION=3.9.2
ARG CYTHON_VERSION=3.0.12
ARG SETUPTOOLS_SCM_VERSION=8.2.0

ENV DEBIAN_FRONTEND=noninteractive
ENV VIRTUAL_ENV=/opt/oxdna/venv
ENV PATH=/opt/oxdna/venv/bin:${PATH}
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_NO_CACHE_DIR=1

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      libopenmpi-dev \
      openmpi-bin; \
    rm -rf /var/lib/apt/lists/*; \
    python -m venv "${VIRTUAL_ENV}"; \
    python -m pip install --no-cache-dir \
      "pip==25.1.1" \
      "setuptools==80.9.0" \
      "wheel==0.45.1" \
      "setuptools-scm==${SETUPTOOLS_SCM_VERSION}" \
      "Cython==${CYTHON_VERSION}" \
      "numpy==${NUMPY_VERSION}" \
      "scipy==${SCIPY_VERSION}" \
      "scikit-learn==${SCIKIT_LEARN_VERSION}" \
      "matplotlib==${MATPLOTLIB_VERSION}"

RUN set -eux; \
    curl -fsSL --retry 5 --retry-delay 2 \
      -o /tmp/oxdna.tar.gz \
      "https://github.com/lorenzo-rovigatti/oxDNA/archive/refs/tags/${OXDNA_TAG}.tar.gz"; \
    echo "${OXDNA_SHA256}  /tmp/oxdna.tar.gz" | sha256sum -c -; \
    mkdir -p /tmp/oxdna; \
    tar -xzf /tmp/oxdna.tar.gz --strip-components=1 -C /tmp/oxdna; \
    sed -i \
      '/# get the current git revision/,/ENDIF(Git_FOUND)/c\SET(revision "b78d23c")\nSET(tag "v3.7.0")' \
      /tmp/oxdna/CMakeLists.txt; \
    sed -i 's/CURRENT_DATE(today)/SET(today "16\/11\/24")/' /tmp/oxdna/CMakeLists.txt; \
    sed -i \
      's|DD12_PDB_PATH = "./UTILS/dd12_na.pdb"|DD12_PDB_PATH = os.path.join(os.path.dirname(__file__), "UTILS", "dd12_na.pdb")|' \
      /tmp/oxdna/analysis/src/oxDNA_analysis_tools/oxDNA_PDB.py; \
    sed -i \
      's|RNA_PDB_PATH = "./UTILS/2jxq.pdb"|RNA_PDB_PATH = os.path.join(os.path.dirname(__file__), "UTILS", "2jxq.pdb")|' \
      /tmp/oxdna/analysis/src/oxDNA_analysis_tools/oxDNA_PDB.py; \
    grep -Fx 'SET(revision "b78d23c")' /tmp/oxdna/CMakeLists.txt; \
    grep -F 'os.path.join(os.path.dirname(__file__), "UTILS", "dd12_na.pdb")' \
      /tmp/oxdna/analysis/src/oxDNA_analysis_tools/oxDNA_PDB.py

RUN set -eux; \
    cmake -S /tmp/oxdna -B /tmp/oxdna-build-cpu \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
      -DCUDA=OFF \
      -DMPI=OFF \
      -DNATIVE_COMPILATION=OFF \
      -DJSON_ENABLED=ON \
      -DPython=ON \
      -DPYTHON_EXECUTABLE="${VIRTUAL_ENV}/bin/python"; \
    cmake --build /tmp/oxdna-build-cpu --parallel 2; \
    cmake -S /tmp/oxdna -B /tmp/oxdna-build-mpi \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
      -DCUDA=OFF \
      -DMPI=ON \
      -DNATIVE_COMPILATION=OFF \
      -DJSON_ENABLED=ON \
      -DPython=OFF; \
    cmake --build /tmp/oxdna-build-mpi --target oxDNA_mpi --parallel 2

RUN set -eux; \
    python -m pip install --no-cache-dir --no-build-isolation --no-deps /tmp/oxdna/analysis; \
    SETUPTOOLS_SCM_PRETEND_VERSION_FOR_OXPY="${OXDNA_VERSION}" \
      python -m pip install --no-cache-dir --no-build-isolation --no-deps \
      /tmp/oxdna-build-cpu/oxpy/python/oxpy; \
    python -c 'import importlib.metadata as md; import oxpy, oxDNA_analysis_tools; assert md.version("oxpy") == "3.7.0"; assert md.version("oxDNA-analysis-tools") == "2.5.0"; print(md.version("oxpy"), oxDNA_analysis_tools.__version__)'

RUN set -eux; \
    mkdir -p /opt/oxdna/bin /opt/oxdna/share/doc/oxdna /opt/oxdna/source; \
    install -m 0755 /tmp/oxdna-build-cpu/bin/oxDNA /opt/oxdna/bin/oxDNA; \
    install -m 0755 /tmp/oxdna-build-cpu/bin/DNAnalysis /opt/oxdna/bin/DNAnalysis; \
    install -m 0755 /tmp/oxdna-build-cpu/bin/confGenerator /opt/oxdna/bin/confGenerator; \
    install -m 0755 /tmp/oxdna-build-mpi/bin/oxDNA_mpi /opt/oxdna/bin/oxDNA_mpi; \
    cp -a /tmp/oxdna/. /opt/oxdna/source/; \
    printf '%s\n' \
      "upstream=lorenzo-rovigatti/oxDNA" \
      "version=${OXDNA_VERSION}" \
      "tag=${OXDNA_TAG}" \
      "commit=${OXDNA_COMMIT}" \
      "source=https://github.com/lorenzo-rovigatti/oxDNA/archive/refs/tags/${OXDNA_TAG}.tar.gz" \
      "sha256=${OXDNA_SHA256}" \
      "oat_version=${OAT_VERSION}" \
      'build=portable CPU double precision, JSON, oxpy, and MPI; native ISA and LTO disabled; CUDA disabled' \
      'patch=embed release metadata and resolve OAT reference PDB files relative to the installed package' \
      'launchers=preserve upstream utility source paths and Python interpreter selection' \
      > /opt/oxdna/share/doc/oxdna/source.txt; \
    python -c 'import importlib.metadata as md; rows=sorted((d.metadata.get("Name", d.metadata["Name"]), d.version) for d in md.distributions()); open("/opt/oxdna/share/doc/oxdna/installed-python-packages.tsv", "w").write("package\tversion\n" + "".join(f"{n}\t{v}\n" for n,v in rows))'; \
    strip --strip-unneeded /opt/oxdna/bin/oxDNA /opt/oxdna/bin/DNAnalysis \
      /opt/oxdna/bin/confGenerator /opt/oxdna/bin/oxDNA_mpi; \
    find "${VIRTUAL_ENV}" -type f -path '*/oxpy/core.so' -exec strip --strip-unneeded '{}' +; \
    find "${VIRTUAL_ENV}" -type f -path '*/oxDNA_analysis_tools/UTILS/*.so' \
      -exec strip --strip-unneeded '{}' +; \
    find "${VIRTUAL_ENV}" -type f -name direct_url.json -delete; \
    find "${VIRTUAL_ENV}" -type d \( -name __pycache__ -o -name tests -o -name test \) \
      -prune -exec rm -rf '{}' +; \
    find "${VIRTUAL_ENV}" -type d \( -name include -o -name headers \) \
      -prune -exec rm -rf '{}' +; \
    python -m pip uninstall -y Cython setuptools-scm wheel pip; \
    find "${VIRTUAL_ENV}" -type d -name __pycache__ -prune -exec rm -rf '{}' +; \
    rm -rf /opt/oxdna/source/.github \
      /opt/oxdna/source/.settings \
      /opt/oxdna/source/analysis/build \
      /opt/oxdna/source/analysis/paper_examples \
      /opt/oxdna/source/examples/BOILERPLATE_Jupyter/.ipynb_checkpoints \
      /opt/oxdna/source/examples/OXPY_Jupyter/.ipynb_checkpoints \
      /tmp/* /root/.cache

FROM ${PYTHON_IMAGE}

ARG OXDNA_VERSION=3.7.0
ARG OXDNA_COMMIT=b78d23c73c26571eb36def3a2f59f586585461ae
ARG OAT_VERSION=2.5.0

LABEL maintainer="taffish@163.com"

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      libgomp1 \
      libopenmpi3 \
      openmpi-bin; \
    apt-get clean; \
    find /usr/share/doc -type f ! -name copyright -delete; \
    find /usr/share/doc -type l -delete; \
    find /usr/share/doc -depth -type d -empty -delete; \
    rm -rf /usr/share/man/* /usr/share/info/* /usr/share/locale/*; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /root/.cache; \
    rm -rf /usr/local/lib/python3.11/site-packages/pip* \
      /usr/local/lib/python3.11/site-packages/setuptools* \
      /usr/local/lib/python3.11/site-packages/wheel* \
      /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip3.11

COPY --from=builder /opt/oxdna /opt/oxdna
COPY docker/bin/oxdna-convert-topology /usr/local/bin/oxdna-convert-topology
COPY docker/bin/oxdna-generate-sa /usr/local/bin/oxdna-generate-sa
COPY docker/testdata/oxdna-smoke.sh /opt/oxdna/share/testdata/oxdna-smoke.sh

ENV OXDNA_ROOT=/opt/oxdna
ENV OXDNA_SOURCE=/opt/oxdna/source
ENV VIRTUAL_ENV=/opt/oxdna/venv
ENV PATH=/opt/oxdna/bin:/opt/oxdna/venv/bin:${PATH}
ENV MPLBACKEND=Agg
ENV XDG_CACHE_HOME=/tmp/xdg-cache
ENV PYTHONDONTWRITEBYTECODE=1
ENV OXDNA_VERSION=${OXDNA_VERSION}
ENV OXDNA_COMMIT=${OXDNA_COMMIT}
ENV OAT_VERSION=${OAT_VERSION}

RUN set -eux; \
    chmod 0755 /usr/local/bin/oxdna-convert-topology \
      /usr/local/bin/oxdna-generate-sa \
      /opt/oxdna/share/testdata/oxdna-smoke.sh; \
    chmod 0755 /opt/oxdna/source/utils/generate-sa.py /opt/oxdna/source/utils/convert.py; \
    ln -s /opt/oxdna/bin/oxDNA /usr/local/bin/oxDNA; \
    ln -s /opt/oxdna/bin/DNAnalysis /usr/local/bin/DNAnalysis; \
    ln -s /opt/oxdna/bin/confGenerator /usr/local/bin/confGenerator; \
    ln -s /opt/oxdna/bin/oxDNA_mpi /usr/local/bin/oxDNA_mpi; \
    ln -s /opt/oxdna/venv/bin/python /usr/local/bin/oxdna-python; \
    /opt/oxdna/share/testdata/oxdna-smoke.sh identity; \
    /opt/oxdna/share/testdata/oxdna-smoke.sh simulation; \
    ldd /opt/oxdna/bin/oxDNA /opt/oxdna/bin/DNAnalysis \
      /opt/oxdna/bin/confGenerator /opt/oxdna/bin/oxDNA_mpi \
      > /tmp/oxdna-ldd.txt; \
    find /opt/oxdna/venv -type f -name '*.so' \
      ! -path '*/site-packages/*.libs/*' -print0 \
      | xargs -0 -r ldd >> /tmp/oxdna-ldd.txt; \
    if grep -F 'not found' /tmp/oxdna-ldd.txt; then exit 1; fi; \
    rm -rf /tmp/taf-oxdna-* /tmp/xdg-cache /tmp/oxdna-ldd.txt /root/.cache

WORKDIR /root

ENV TAFFISH_ENV=TAFFISH
ENV TAFFISH_NAME=oxdna
