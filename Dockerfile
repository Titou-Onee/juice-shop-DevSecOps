FROM cgr.dev/chainguard/crane:latest@sha256:0a4dc3be3dbd6b7fcb85e334399c796d1e8866731d38a5a2b267966c0e17692c AS crane-bin

FROM ghcr.io/sigstore/cosign/cosign:v2.4.1@sha256:b03690aa52bfe94054187142fba24dc54137650682810633901767d8a3e15b31 AS cosign-bin
FROM anchore/grype:0.112.0-nonroot@sha256:7b2a833a2b80732c0342b0e2ecf33d0ec9f5d1a2eadddd267a6341c545908a4e AS grype-bin
FROM anchore/syft:v1.43.0-nonroot@sha256:cd4dcc905d87315e98c08d86948f9cad40245ad7dc8e6924d2860b464ab4afa8 AS syft-bin
FROM scaleway/cli:2.55@sha256:59884343f2ce6579643e88f3e943ac47a5d49df7488b0fcf3d95268ea0aa0ce1 AS scw-cli-bin

FROM jenkins/ssh-agent:debian-jdk21@sha256:dd248d1b08592061c65f7d1cbafaa6aaa0ffd8df1139debfc43b4df80e9c41ce
USER root

COPY --from=crane-bin /usr/bin/crane /usr/local/bin/crane

COPY vault/vault/tls/cert.pem /usr/local/share/ca-certificates/my-internal-ca.crt
RUN update-ca-certificates

# Cosign chainguard 
COPY --chmod=755 --from=cosign-bin /ko-app/cosign       /usr/local/bin/cosign
COPY --chmod=755 --from=syft-bin   /syft  /usr/local/bin/syft
COPY --chmod=755 --from=grype-bin  /grype /usr/local/bin/grype
COPY --chmod=755 --from=scw-cli-bin /usr/local/bin/scw  /usr/local/bin/scw


ARG DOCKER_GID=999
RUN groupadd -f -g 127 docker \
&& usermod -aG docker jenkins 

# apt-get with pinned versions
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3=3.13.5-1 \
    python3-pip=25.1.1+dfsg-1 \
    python3-venv=3.13.5-1 \
    gnupg=2.4.7-21+deb13u1 \
    jq=1.7.1-6+deb13u1 \
    nodejs=20.19.2+dfsg-1+deb13u2 \
    npm=9.2.0~ds1-3 \
    curl=8.14.1-2+deb13u2 \
    lsb-release=12.1-1 \
    && rm -rf /var/lib/apt/lists/*

# Semgrep
RUN python3 -m venv /opt/semgrep-venv && \
    /opt/semgrep-venv/bin/pip install --upgrade pip && \
    /opt/semgrep-venv/bin/pip install semgrep==v1.161.0

# Trivy with pinned version
RUN set -o pipefail && curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list \
    FINGERPRINT=$(gpg --no-default-keyring --keyring /usr/share/keyrings/trivy.gpg --fingerprint --with-colons | grep '^fpr' | cut -d: -f10) && \
    if [ "$FINGERPRINT" != "825AD9036F7C850E6A6FED4935B8ACA44FD9CA9F"]; then \
        echo "ERREUR :  invalid fingerprint Trivy — build canceled"; exit 1; \
    fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends trivy=0.70.0 \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI with pinned version
RUN set -o pipefail && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    FINGERPRINT=$(gpg --no-default-keyring --keyring /usr/share/keyrings/docker.asc --fingerprint --with-colons | grep '^fpr' | cut -d: -f10) && \
    if [ "$FINGERPRINT" != "9DC858229FC7DD38854AE2D88D81803C0EBFCD88"]; then \
        echo "ERREUR :  invalid fingerprint Trivy — build canceled"; exit 1; \
    fi \
    && apt-get update \
    && apt-get install --no-install-recommends -y docker-ce-cli=5:29.4.2-1~debian.13~trixie \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Cache Grype
RUN mkdir -p /opt/grype-db && chown -R jenkins:jenkins /opt/grype-db
ENV GRYPE_DB_CACHE_DIR=/opt/grype-db
ENV GRYPE_DB_AUTO_UPDATE=false

#Last User is root in Jenkins Agents