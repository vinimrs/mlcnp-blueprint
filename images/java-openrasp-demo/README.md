# Java workload with OpenRASP

This image supplies the execution boundary of the generic MLCNP deployment. It combines Tomcat 9 with the OpenRASP 1.3.7 Java agent downloaded from the official release and verified by SHA-256 during the build.

Build for the architecture supported by the OpenRASP native engine:

```bash
docker build --platform linux/amd64 \
  --tag mlcnp/java-openrasp-demo:local \
  --file images/java-openrasp-demo/Dockerfile .
```

The Kubernetes manifest starts Tomcat with:

```text
-javaagent:/opt/rasp/rasp.jar
```

The agent writes its runtime logs below `/opt/rasp/logs` and adds `X-Protected-By: OpenRASP` to application responses. The container runs as UID/GID `10001`, uses a read-only root filesystem in the supplied Kubernetes manifest, and includes project and third-party license notices under `/licenses`.
