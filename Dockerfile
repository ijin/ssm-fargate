FROM golang:1.16.0-alpine3.13 AS ssm

ARG SSM_AGENT_VERSION=3.0.755.0

RUN set -ex && apk add --no-cache make git gcc libc-dev bash && \
    wget -q https://github.com/aws/amazon-ssm-agent/archive/${SSM_AGENT_VERSION}.tar.gz && \
    mkdir -p /go/src/github.com && \
    tar xzf ${SSM_AGENT_VERSION}.tar.gz && \
    mv amazon-ssm-agent-${SSM_AGENT_VERSION} /go/src/github.com/amazon-ssm-agent && \
    cd /go/src/github.com/amazon-ssm-agent && \
    echo ${SSM_AGENT_VERSION} > VERSION && \
    go env -w GO111MODULE=auto && \
    gofmt -w agent && make checkstyle || ./Tools/bin/goimports -w agent && \
    make build-linux


FROM alpine:3.13 AS cli

RUN apk add --no-cache \
    acl \
    fcgi \
    file \
    gettext \
    git \
    curl \
    unzip\
    python3-dev \
    py3-pip \
    gcc \
    linux-headers \
    musl-dev \
    libffi-dev \
    openssl-dev

ARG AWS_CLI_VERSION=2.1.28

RUN git clone --recursive  --depth 1 --branch $AWS_CLI_VERSION --single-branch  https://github.com/aws/aws-cli.git

WORKDIR aws-cli

RUN pip install --ignore-installed -r requirements.txt
RUN pip install -e .
RUN aws --version


FROM alpine:3.13


RUN set -ex && apk add --no-cache python3 sudo curl openssl ca-certificates && \
    adduser -D ssm-user && echo "ssm-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ssm-agent-users && \
    mkdir -p /etc/amazon/ssm

COPY --from=ssm /go/src/github.com/amazon-ssm-agent/bin/linux_amd64/ /usr/bin
COPY --from=ssm /go/src/github.com/amazon-ssm-agent/bin/amazon-ssm-agent.json.template /etc/amazon/ssm/amazon-ssm-agent.json
COPY --from=ssm /go/src/github.com/amazon-ssm-agent/bin/seelog_unix.xml /etc/amazon/ssm/seelog.xml


COPY --from=cli /usr/bin/aws* /usr/bin/
COPY --from=cli /usr/lib/python3.8/site-packages /usr/lib/python3.8/site-packages
COPY --from=cli /aws-cli /aws-cli


ENV AWS_DEFAULT_REGION=ap-northeast-1
ENV SSM_AGENT_CODE=
ENV SSM_AGENT_ID=


COPY run.sh .

ENTRYPOINT ["sh", "./run.sh"]

CMD ["sleep infinity"]

