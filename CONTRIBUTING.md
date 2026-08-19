# Contribuindo com o MLCNP Blueprint

Contribuições devem manter o caminho principal pequeno, reproduzível e executável com `kubectl`.

1. descreva a motivação e o efeito da mudança;
2. preserve o fluxo gateway → Service → sidecar → aplicação com RASP;
3. atualize o diagrama quando a topologia mudar;
4. execute `make validate` antes de abrir a pull request;
5. execute `make verify` quando a mudança afetar o comportamento em runtime;
6. mantenha binários de terceiros e resultados gerados fora do Git.


Ao contribuir, você concorda que sua contribuição será licenciada sob Apache-2.0.
