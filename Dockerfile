FROM ubuntu
RUN apt update && apt install jq -y && apt install git -y
COPY build.sh .
COPY BP-BASE-SHELL-STEPS .
RUN chmod +x build.sh
ENV ACTIVITY_SUB_TASK_CODE BP-ECR-REPO-CREATION-TASK
ENV SLEEP_DURATION 0s
ENV TAG_NAME ""
ENTRYPOINT [ "./build.sh" ]
