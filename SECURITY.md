# Política de segurança

## Uso do blueprint

O MLCNP Blueprint oferece uma implementação de referência para ambientes locais e clusters isolados.

- mantenha o gateway acessível localmente com `kubectl port-forward` durante a avaliação;
- use imagens e agentes revisados pela sua organização;
- mantenha credenciais, imagens privadas e dados reais fora do repositório;
- aplique os controles organizacionais de identidade, segredos e cadeia de suprimentos antes de uma implantação pública;
- remova o ambiente com `make uninstall` quando concluir a avaliação.

O OpenRASP 1.3.7 contém componentes nativos `linux/amd64`; por isso, a imagem de referência é construída localmente para essa arquitetura. Antes de distribuir uma imagem derivada, faça uma nova análise de vulnerabilidades e substitua dependências que não atendam à política da sua organização.

## Relato de vulnerabilidades

Envie o relato pelo [canal privado de segurança do GitHub](https://github.com/vinimrs/mlcnp-blueprint/security/advisories/new). Inclua a versão utilizada, o impacto observado e os passos mínimos para reprodução. Não abra uma issue pública para uma vulnerabilidade ainda não divulgada.
