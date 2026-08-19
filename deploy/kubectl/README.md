# Instalação com kubectl

Este diretório reúne todos os objetos necessários para executar as três fronteiras da MLCNP:

```text
Service/mlcnp-gateway :8080
  → gateway com ModSecurity e OWASP CRS
    → Service/mlcnp-application :8081
      → sidecar-proxy nginx :8081
        → application-with-rasp :8080
```

O sidecar e a aplicação compartilham o mesmo Pod. O Service do workload direciona o tráfego para a porta nomeada `proxy`, e o sidecar alcança a aplicação por `127.0.0.1:8080`.

## Instalação local

Na raiz do repositório:

```bash
minikube start --cni=calico

docker build --platform linux/amd64 \
  --tag mlcnp/java-openrasp-demo:local \
  --file images/java-openrasp-demo/Dockerfile .

minikube image load mlcnp/java-openrasp-demo:local
kubectl apply -k deploy/kubectl
```

Aguarde os componentes:

```bash
kubectl -n mlcnp-blueprint rollout status deployment/mlcnp-gateway --timeout=8m
kubectl -n mlcnp-blueprint rollout status deployment/mlcnp-application --timeout=8m
```

O manifesto inclui o namespace `mlcnp-blueprint`, portanto uma única aplicação do Kustomize instala todo o conjunto.

## Acesso

```bash
kubectl -n mlcnp-blueprint port-forward service/mlcnp-gateway 18080:8080
```

Em outro terminal:

```bash
curl --include http://127.0.0.1:18080/application/
```

A resposta esperada inclui:

```text
X-MLCNP-Gateway: modsecurity-crs
X-MLCNP-Sidecar: nginx
X-MLCNP-Sidecar-Policy: baseline-v1
X-Protected-By: OpenRASP
```

## Controles do sidecar

A política `baseline-v1` configura:

- limite de corpo de requisição de 1 MiB;
- bloqueio de métodos fora da lista HTTP utilizada pelo template;
- timeouts de conexão, envio e leitura;
- remoção de `X-Powered-By` recebido da aplicação;
- cabeçalho `X-Content-Type-Options: nosniff`.

Execute a validação completa com:

```bash
make verify
```

## Uso de uma imagem publicada

Altere o bloco `images` em `kustomization.yaml`:

```yaml
images:
  - name: mlcnp/java-openrasp-demo
    newName: ghcr.io/sua-organizacao/sua-aplicacao
    newTag: 1.0.0
```

O workload usa `imagePullPolicy: IfNotPresent`. Dessa forma, o mesmo manifesto aceita uma imagem carregada localmente ou disponível em um registry.

## Inspeção

```bash
kubectl -n mlcnp-blueprint get deployments,pods,services,networkpolicies

kubectl -n mlcnp-blueprint get deployment mlcnp-application \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}:{.image}{"\n"}{end}'

kubectl -n mlcnp-blueprint get service mlcnp-application \
  -o jsonpath='{range .spec.ports[*]}{.name}:{.port}->{.targetPort}{"\n"}{end}'
```

Os dois últimos comandos mostram os containers `application-with-rasp` e `sidecar-proxy`, seguidos por `http-sidecar:8081->proxy`.

## Remoção

```bash
kubectl delete -k deploy/kubectl
minikube stop
```

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `namespace.yaml` | namespace dedicado |
| `gateway.yaml` | gateway, WAF e Service de entrada |
| `workload.yaml` | aplicação, RASP, sidecar e Service do workload |
| `network-policies.yaml` | fluxos de rede autorizados |
| `kustomization.yaml` | composição, labels e imagem selecionada |
