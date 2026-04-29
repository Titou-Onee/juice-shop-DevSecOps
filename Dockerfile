FROM gcr.io/go-containerregistry/crane:debug AS crane-source

FROM jenkins/ssh-agent:debian-jdk17
USER root

COPY --from=crane-source /ko-app/crane /usr/local/bin/crane

COPY vault/vault/tls/cert.pem /usr/local/share/ca-certificates/my-internal-ca.crt
RUN update-ca-certificates

ARG DOCKER_GID=999
RUN groupadd -f -g 127 docker \
&& usermod -aG docker jenkins 

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    wget \
    gnupg \
    jq \
    nodejs \
    npm \
    ca-certificates \
    curl \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Trivy
RUN wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list \
    && apt-get update \
    && apt-get install -y trivy \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Syft, Cosign, grype
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin v1.3.0
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
RUN curl -sSfL https://github.com/sigstore/cosign/releases/download/v2.2.3/cosign-linux-amd64 -o /usr/local/bin/cosign \
    && chmod +x /usr/local/bin/cosign

# Scaleway CLI
RUN ARCH=$(dpkg --print-architecture) && \
    curl -sLo /usr/local/bin/scw https://github.com/scaleway/scaleway-cli/releases/latest/download/scw-linux-$ARCH && \
    chmod +x /usr/local/bin/scw

# Cache Grype
RUN mkdir -p /opt/grype-db && chown -R jenkins:jenkins /opt/grype-db
ENV GRYPE_DB_CACHE_DIR=/opt/grype-db
ENV GRYPE_DB_AUTO_UPDATE=true

USER jenkins