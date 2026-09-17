# Roadmap — Orquestrador Local

Referência canônica: Vault → `Orquestrador-Local-Plano.md`. Este arquivo é resumo executivo.

> **Nota:** o Vault registra G2 como abrangendo T01–T23 e V1 como rótulo final. Este checkout corrige a ordenação linear dos gates e separa F6/G3 explicitamente. A mesma ambiguidade existe no Vault e deve ser reconciliada em revisão autorizada futura — não alterar o Vault nesta tarefa.

## Sequência de fases e gates

```
F0 Descoberta → G0 → F1 Fundação → F2 Controle → F3 Interface → G1
                                                                   │
                                                               F4 Pilotos
                                                                   │
                                                               F5 Robustez
                                                                   │
                                                                  G2
                                                                   │
                                                               F6 Entrega
                                                                   │
                                                                  G3 = V1
```

## Gates

| Gate | Posição | Critério mínimo |
|---|---|---|
| G0 | Após F0 | Fichas viáveis dos dois candidatos; contratos de controle documentados; escopo aprovado |
| G1 | Após F3 | João libera janela de iniciar/parar; backup dos plists feito; candidatos sem trabalho ativo confirmado |
| G2 | Após F5 | T01–T21 aprovados; nenhum teste obrigatório pulado; nenhum encerramento indevido ou perda de dados |
| G3 | Após F6 | T01–T23 aprovados + três sessões reais de João + aceite explícito com versão e data = **V1 FUNCIONAL LOCAL** |

T22 (pacote local sem Xcode/terminal) e T23 (três sessões reais) pertencem a F6 e são exigidos para G3, não para G2.

## Estado observado em 2026-09-06

F0, F1–F3 e F6 têm evidências parciais locais; F4 não foi executada porque G1 não foi liberado. A matriz `evidencias/matriz-aceite-2026-09-06.md` contém os únicos resultados que contam. G0, G1, G2 e G3 permanecem abertos.

## Descrição das fases

| Fase | Objetivo principal | Saída obrigatória |
|---|---|---|
| F0 | Identificar contratos dos dois candidatos | Fichas viáveis; nenhum serviço modificado |
| F1 | Base nativa, catálogo e simulador | App executável com dados sintéticos |
| F2 | Máquina de estados e adaptador LaunchAgent | Ciclo real de serviço sintético isolado |
| F3 | Interface completa, acessibilidade e temas | Fluxos integrados sem terminal |
| F4 | Integrar os dois pilotos reais | Evidências de iniciar/abrir/parar cada piloto |
| F5 | Falhas, recursos e recuperação | Matriz T01–T21 aprovada, sem skips |
| F6 | Empacotamento e uso real | `.app`, manual, três sessões, aceite |

## Estimativa (referência do Vault)

F0: 3–5 h · F1: 3–5 h · F2: 6–10 h · F3: 5–8 h · F4: 5–9 h · F5: 4–7 h · F6: 3–5 h  
**Total: 29–49 h ativas.** Reestimar após G0.

## Executor preferido por fase

| Fase | Executor candidato | Escalada |
|---|---|---|
| F0 inspeção | codex2 (conta secundária, modelo médio) | Escalada a João se bloqueado 3× |
| F1–F3 núcleo | agy / agent | claude somente para falha difícil |
| F4–F5 integração | agent + revisão manual de João | Escalada caso a caso |
| F6 entrega | qualquer + revisão de João | — |

Nunca editar os mesmos arquivos Swift em paralelo. Um executor por fatia.
