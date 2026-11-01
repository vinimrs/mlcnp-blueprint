FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a AS openrasp

ARG OPENRASP_VERSION=1.3.7
ARG OPENRASP_SHA256=93525f326e9c5a353c5b09d2442c66d318e82bd7182149d4dc579bc99d82a0f2

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN apk add --no-cache \
      ca-certificates=20260611-r0 \
      curl=8.14.1-r3 \
      tar=1.35-r3 \
    && curl --fail --location --show-error \
      "https://github.com/baidu/openrasp/releases/download/v${OPENRASP_VERSION}/rasp-java.tar.gz" \
      --output /tmp/openrasp.tar.gz \
    && echo "${OPENRASP_SHA256}  /tmp/openrasp.tar.gz" | sha256sum -c - \
    && mkdir -p /opt/rasp \
    && tar -xzf /tmp/openrasp.tar.gz -C /opt/rasp --strip-components=2 \
    && test -s /opt/rasp/rasp.jar \
    && test -s /opt/rasp/rasp-engine.jar

FROM tomcat:9.0.121-jdk11-temurin-jammy@sha256:e3ce46968c91d48ec3318f67f0064aacf96312dcebf1fc3e422f2d8a4162c0cf

LABEL org.opencontainers.image.title="MLCNP Java OpenRASP demo"
LABEL org.opencontainers.image.description="Tomcat workload with the OpenRASP Java agent installed"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/vinimrs/mlcnp-blueprint"

RUN groupadd --gid 10001 mlcnp \
    && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin mlcnp

COPY --chown=10001:10001 --from=openrasp /opt/rasp /opt/rasp
COPY --chown=10001:10001 images/java-openrasp-demo/index.jsp /usr/local/tomcat/webapps/ROOT/index.jsp
COPY LICENSE /licenses/mlcnp/LICENSE
COPY third_party/openrasp/LICENSE /licenses/openrasp/LICENSE
COPY NOTICE THIRD_PARTY_NOTICES.md /licenses/mlcnp/

RUN mkdir -p \
      /opt/rasp/logs \
      /usr/local/tomcat/logs \
      /usr/local/tomcat/temp \
      /usr/local/tomcat/work \
    && chown -R 10001:10001 /opt/rasp /usr/local/tomcat

ENV JAVA_TOOL_OPTIONS="--add-opens=java.base/jdk.internal.loader=ALL-UNNAMED -javaagent:/opt/rasp/rasp.jar"

EXPOSE 8080

USER 10001:10001
