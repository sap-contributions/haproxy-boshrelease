FROM ghcr.io/cloudfoundry/bosh/docker-cpi:latest

# Install all necessary tools for haproxy testflight and dependency autobump
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y wget jq git vim nano python3-pip python3-venv && \
    apt-get install -y build-essential zlib1g-dev ruby ruby-dev openssl libxslt1-dev libxml2-dev libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 && \
    apt-get clean

# Install bosh cli v2
RUN wget -O ./bosh https://github.com/cloudfoundry/bosh-cli/releases/download/v7.9.18/bosh-cli-7.9.18-linux-amd64 && \
    chmod +x ./bosh && \
    mv ./bosh /usr/local/bin/bosh && \
    bosh -v

# Set bosh env at login
RUN echo "source /tmp/local-bosh/director/docker-env" >> /root/.bashrc
RUN echo "source /tmp/local-bosh/director/env" >> /root/.bashrc

RUN mkdir -p /usr/local/bosh-deployment/haproxy-boshrelease

# Make local BPM release
RUN git clone https://github.com/cloudfoundry/bpm-release.git && cd bpm-release && git apply ../local-releases/bpm-del-runc-state.patch
RUN bosh create-release --force --timestamp-version --tarball=bpm-patched-dev-release.tgz
COPY bpm-patched-dev-release.tgz /usr/local/bosh-deployment/haproxy-boshrelease/bpm-patched-dev-release.tgz
RUN cd .. && rm -rf bpm-release

# Copy ops files
COPY ops/bosh-scaled-out.yml /usr/local/bosh-deployment/haproxy-boshrelease/bosh-scaled-out.yml
COPY ops/bosh-timeouts.yml /usr/local/bosh-deployment/haproxy-boshrelease/bosh-timeouts.yml
COPY ops/compilation.yml /usr/local/bosh-deployment/haproxy-boshrelease/compilation.yml
COPY ops/local-releases.yml /usr/local/bosh-deployment/haproxy-boshrelease/local-releases.yml

# Install Python libraries needed for scripts
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
COPY scripts/requirements.txt /requirements.txt
RUN pip install -r /requirements.txt

# Install go dependencies
ENV GOBIN=/usr/local/bin
RUN go install github.com/geofffranks/spruce/cmd/spruce@latest