# PROMPT-F0-CODEX2 — Inspeção F0 somente leitura

**Status:** PREPARADO — NÃO DESPACHADO  
**Executor alvo:** codex2 (conta secundária)  
**Preparado em:** 2026-09-06

---

## Instruções de lançamento (separadas do prompt — não misturar)

O comando abaixo foi verificado localmente pelo orquestrador. Não executar sem autorização explícita do operador João.

```bash
/Users/joaopaulo/.local/bin/codex2 exec \
  --ignore-user-config \
  --sandbox read-only \
  --cd /Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal \
  --skip-git-repo-check \
  --ephemeral \
  - < /Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/contexto/PROMPT-F0-CODEX2.md
```

> Verificação de sintaxe: fornecida pelo orquestrador; não testada por este documento. Confirmar que codex2 está autenticado antes de despachar.

---

## Task prompt (English — content that flows to stdin begins here)

You are the F0 discovery executor for **Orquestrador Local**, a proposed personal macOS app for starting, observing, opening and safely stopping two registered local service candidates.

**Execute this F0 discovery task only when this prompt is explicitly dispatched by the operator. Do not start F1 or any implementation work.**

### What you must NOT do

- Modify any file (project, Vault, LaunchAgents, configuration, code, database, volumes)
- Start, stop, restart or signal any service or process
- Install, update or remove any dependency or package
- Initialize or modify Git state (no init, commit, tag, push)
- Read credentials, `.env` file contents, authentication stores, complete log files, or process arguments that may contain secrets or tokens
- Read or dump environment variables from any running process
- Make mutating HTTP requests or follow remote redirects
- Delegate to any other agent or external connector
- Infer a service is stopped or ready from a permission failure — report it as UNKNOWN

### Context to read before inspecting

Read the following files from the project root at `/Users/joaopaulo/Documents/Projetos/Pessoal/OrquestradorLocal/`:

1. `INDEX.md`
2. `ESTADO_ATUAL.md`
3. `ROADMAP.md`
4. `CLAUDE_ORQUESTRADOR.md`
5. `contexto/ficha-mflux-studio.md`
6. `contexto/ficha-comfyui.md`
7. `contexto/ADR-001-tecnologia.md`

Read the following Vault notes as reference (read-only; do not modify):

- `Projetos/Pessoal/Orquestrador-Local.md`
- `Projetos/Pessoal/Orquestrador-Local/INDEX.md`
- `Projetos/Pessoal/Orquestrador-Local/Cadastro-e-Integracoes.md`
- `Projetos/Pessoal/Orquestrador-Local/Seguranca-e-Operacao.md`
- `Projetos/Pessoal/Orquestrador-Local/Aceite-V1.md`
- `Projetos/Carreira/mflux-studio.md`

Vault root: `/Users/joaopaulo/Library/CloudStorage/GoogleDrive-jpna54@gmail.com/Meu Drive/Obsidian Vault/`

Report any file not found rather than assuming its contents.

---

### Inspection scope — mflux-studio (read-only)

1. List the directory `/Users/joaopaulo/Documents/Projetos/Carreira/mflux-studio/` — names and types only.
2. Read `contexto/INDEX.md`, `ESTADO_ATUAL.md`, `ROADMAP.md`, `CLAUDE_ORQUESTRADOR.md` under that project if present; report missing files without assuming their contents.
3. Read `~/Library/LaunchAgents/local.mflux-studio.plist`. Extract and report **only** these fields: `Program`, `ProgramArguments` (first element only — the executable path; omit all subsequent arguments that may contain secrets, tokens, model paths or private data), `KeepAlive`, `RunAtLoad`, `StandardOutPath`, `StandardErrorPath`. Never display `EnvironmentVariables` or any dict that may carry credentials.
4. Read `~/Library/LaunchAgents/com.joaopaulo.mflux-studio.plist` — same fields and same restrictions.
5. Run `launchctl list | grep -i mflux` — record the full output of this single command.
6. Consult `man launchctl` locally. Record the relevant excerpt for `bootout` and `remove` semantics in the user domain on this macOS version. Do not propose migration steps — that belongs to gate G1.
7. Read `server.py` in the mflux-studio directory. Report whether it exposes any endpoint that could serve as an activity or job-queue signal. Do not call that endpoint.
8. Record the log file paths from `StandardOutPath`/`StandardErrorPath` in the plists. Do not read or dump log file contents.

For each item: report current observation, source, and whether it matches or diverges from the historical snapshots in the project ficha. Explicitly distinguish the September 4, 2026 historical note from the September 6, 2026 audit snapshot from the current observation.

Do not diagnose the cause of exit 126 beyond what the plist and log path reveal read-only. A permission failure reading any file or output is UNKNOWN, not stopped or passed.

---

### Inspection scope — ComfyUI (read-only)

1. Search for a ComfyUI installation by checking these locations in order (report which exist):
   - `/Users/joaopaulo/ComfyUI`
   - `~/Documents/ComfyUI`
   - `~/Documents/Projetos/ComfyUI`
   - `~/opt/ComfyUI`
   - `~/miniforge3/envs/` (list env names only if directory exists)
   - `~/miniconda3/envs/` (list env names only if directory exists)
2. For any found installation: list the root directory (names and types only) and the `models/` subdirectory names only.
3. Check `~/Library/LaunchAgents/` for any plist whose filename or `Label` field references ComfyUI — apply the same field filter as for mflux-studio.
4. Run `launchctl list | grep -i comfy` — record the full output.
5. Run `ps -eo pid,ppid,%cpu,rss,comm | grep -i comfy | grep -v grep` — record output. Do not collect full argument lists (`args` or `command` columns that show all argv). If this command returns results, note PID and executable name only.
6. Make a single read-only GET request to `http://127.0.0.1:8188/system_stats` with a 3-second timeout. Record: HTTP status, and if 200, the top-level keys of the JSON body only — no nested values. If the request fails or times out, record UNKNOWN.
7. Make a single read-only GET request to `http://127.0.0.1:8188/queue` with a 3-second timeout. Record: HTTP status, and if 200, the values of `queue_running` and `queue_pending` (counts or array lengths only — not the full payload). If the request fails or times out, record UNKNOWN.
8. From the found installation's source or config, identify the Python executable or venv used. Record the path — do not run Python.

**If ComfyUI is not running via a user LaunchAgent:** explicitly flag this as a potential gate failure for the V1 LaunchAgent adapter. Propose the smallest alternative scope without expanding the adapter design. Do not implement or configure anything.

---

### Ownership, readiness and activity — keep separate

These three concepts must be reported independently for each candidate:

- **Ownership:** which supervisor controls the process; which plist file; which domain. A process running without a known plist means ownership is UNKNOWN.
- **Readiness:** endpoint response and identity verification. HTTP 200 alone is not sufficient — report what the response body or headers reveal about the specific service identity.
- **Activity:** job queue or work signal. Absence of an activity endpoint means activity is UNKNOWN — do not treat UNKNOWN as idle.

A permission failure on any of these dimensions is UNKNOWN for that dimension only. It does not imply the other dimensions are also UNKNOWN or that the service is stopped.

---

### Existing tools brief assessment

Report factual observations only: whether Raycast is installed and whether it has built-in start/stop management for user LaunchAgents with state feedback equivalent to the proposed panel. Do not assume capabilities not confirmed by inspection.

---

### Output format

Return exactly these 10 numbered headings **in Portuguese**. Do not write to any file — return the report as output only.

1. O que foi feito
2. Arquivos alterados
3. Arquivos analisados
4. O que não foi alterado
5. Testes executados
6. Resultado dos testes (include the integration assessment for each candidate, covering: identity, ownership, readiness, activity, safe-stop proposal, shared dependencies, competing startup entries, permission constraints, gate assessment VIABLE/BLOCKED/FAIL)
7. Pendências
8. Riscos
9. Status final: OK ou FALHA (OK = discovery delivered with honest findings, not V1 functional)
10. Próximo passo recomendado

Constraints: no code dumps, no log contents, no secrets, no credentials, no private paths, no personal data. Record every skipped or failed check honestly — never substitute an assumption. Distinguish current evidence from historical snapshots throughout.
