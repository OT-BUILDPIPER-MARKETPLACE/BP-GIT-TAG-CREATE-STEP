FROM ubuntu
RUN apt update && apt install jq -y && apt install git -y
RUN apt-get update && \
    apt-get install -y bash curl python3 python3-pip && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py && \
    pip install cryptography
COPY build.sh .
COPY BP-BASE-SHELL-STEPS .
RUN chmod +x build.sh

ENV CREDENTIAL_USERNAME ""
ENV CREDENTIAL_PASSWORD ""
ENV ACTIVITY_SUB_TASK_CODE BP-GIT-TAG-CREATE-TASK
ENV SLEEP_DURATION 0s
ENV TAG_NAME ""
ENTRYPOINT [ "./build.sh" ]
