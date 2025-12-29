# -------------------------------
# Base image
# -------------------------------
FROM ubuntu:22.04

# -------------------------------
# Install dependencies
# -------------------------------
RUN apt-get update && \
    apt-get install -y \
        jq \
        git \
        bash \
        curl \
        python3 \
        python3-pip \
        sudo && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# -------------------------------
# Install pip and python packages
# -------------------------------
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py && \
    pip install cryptography && \
    rm get-pip.py

# -------------------------------
# Create buildpiper user & group
# -------------------------------
RUN groupadd -g 65522 buildpiper && \
    useradd -u 65522 -g buildpiper -d /home/buildpiper -m -s /bin/bash buildpiper && \
    mkdir -p /bp /bp/workspace /bp/data /home/buildpiper/reports && \
    chown -R buildpiper:buildpiper /bp /home/buildpiper

# -------------------------------
# Copy scripts and set permissions
# -------------------------------
COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/ /opt/buildpiper/shell-functions/

RUN chmod +x /home/buildpiper/build.sh

# -------------------------------
# Set environment defaults
# -------------------------------
ENV CREDENTIAL_USERNAME=""
ENV CREDENTIAL_PASSWORD=""
ENV ACTIVITY_SUB_TASK_CODE="BP-GIT-TAG-CREATE-TASK"
ENV SLEEP_DURATION="0s"
ENV TAG_NAME=""

# -------------------------------
# Switch to non-root user
# -------------------------------
USER buildpiper
WORKDIR /home/buildpiper

# -------------------------------
# Entrypoint
# -------------------------------
ENTRYPOINT [ "./build.sh" ]

