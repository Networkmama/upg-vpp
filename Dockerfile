# syntax = docker/dockerfile:experimental

ARG BUILD_IMAGE=quay.io/travelping/upg-build:latest
FROM $BUILD_IMAGE AS build-stage

ADD vpp /src/vpp
ADD upf /src/upf

RUN --mount=target=/src/vpp/build-root/.ccache,type=cache \
    make -C /src/vpp pkg-deb V=1 && \
    mkdir -p /out/debs && \
    mv /src/vpp/build-root/*.deb /out/debs && \
    tar -C /src/vpp -cvzf /out/testfiles.tar.gz build-root/install-vpp-native

# pseudo-image to extract artifacts using buildctl
FROM scratch as artifacts

COPY --from=build-stage /out .

# --- final image --------------------------------------------
FROM ubuntu:focal AS final-stage
WORKDIR /
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private \
    --mount=target=/var/cache/apt,type=cache,sharing=private \
    apt-get update && apt-get dist-upgrade -yy && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:aschultz/ppa && \
    apt-get install --no-install-recommends -yy liblz4-tool tar

# TODO: add more packages above that are VPP deps
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private \
    --mount=target=/var/cache/apt,type=cache,sharing=private \
    --mount=target=/debs,source=/out/debs,from=build-stage,type=bind \
    VPP_INSTALL_SKIP_SYSCTL=true \
    apt-get install --no-install-recommends -yy \
    /debs/vpp_*.deb \
    /debs/vpp-dbg_*.deb \
    /debs/vpp-plugin-core_*.deb \
    /debs/libvppinfra_*.deb \
    /debs/vpp-api-python_*.deb

ENTRYPOINT /usr/bin/vpp
