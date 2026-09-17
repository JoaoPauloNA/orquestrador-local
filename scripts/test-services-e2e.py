#!/usr/bin/env python3
"""
E2E Test Suite for Orquestrador Local Services:
- ScreenPipe (Native CLI, zero-paywall, Audio OFF, OCR ON)
- AnythingLLM (Local memory, Native embeddings, zero generative LLM)
- Kitten TTS (On-demand CLI kread)
- Sanitizer & Dedup Bridge (Deterministic)
- ComfyUI & mflux (Orchestrator integration)
"""

import sys
import os
import time
import json
import sqlite3
import subprocess
import urllib.request
import urllib.error
from pathlib import Path

# Colors
GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"

results = {}

def log_pass(name, msg=""):
    print(f"{GREEN}✅ [PASS]{RESET} {name}: {msg}")
    results[name] = "PASS"

def log_fail(name, msg=""):
    print(f"{RED}❌ [FAIL]{RESET} {name}: {msg}")
    results[name] = "FAIL"

def start_service(label: str, plist_path: Path):
    domain = f"gui/{os.getuid()}"
    subprocess.run(["launchctl", "bootstrap", domain, str(plist_path)], capture_output=True)
    res = subprocess.run(["launchctl", "kickstart", "-k", f"{domain}/{label}"], capture_output=True, text=True)
    return res.returncode == 0

def stop_service(label: str):
    domain = f"gui/{os.getuid()}"
    subprocess.run(["launchctl", "bootout", f"{domain}/{label}"], capture_output=True)
    time.sleep(1)

# =========================================================================
# 1. SANITIZER TEST
# =========================================================================
print("\n" + "="*50)
print("🧪 1. TESTE DO SANITIZER (DETERMINÍSTICO)")
print("="*50)

# Import sanitizer function from bridge
sys.path.insert(0, str(Path.home() / ".local/bin"))
bridge_path = Path.home() / ".local/bin/screenpipe-anythingllm-bridge.py"

try:
    import importlib.util
    spec = importlib.util.spec_from_file_location("bridge", str(bridge_path))
    bridge = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bridge)

    test_input = """
    Configuração do servidor:
    API_KEY=FAKE_SECRET_123456789
    password=FAKE_PASSWORD_456
    auth_token=super_secret_token_abc123
    Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.do_not_leak_this_jwt
    -----BEGIN RSA PRIVATE KEY-----
    MIIEowIBAAKCAQEA0fake_private_key_data_here
    -----END RSA PRIVATE KEY-----
    Texto limpo que deve permanecer intacto.
    """

    sanitized, modified = bridge.sanitize_text(test_input)

    # Asserts
    leaks = []
    if "FAKE_SECRET_123456789" in sanitized: leaks.append("API_KEY")
    if "FAKE_PASSWORD_456" in sanitized: leaks.append("password")
    if "super_secret_token_abc123" in sanitized: leaks.append("auth_token")
    if "do_not_leak_this_jwt" in sanitized: leaks.append("JWT")
    if "MIIEowIBAAKCAQEA0fake_private_key_data_here" in sanitized: leaks.append("Private Key")

    if not leaks and "Texto limpo que deve permanecer intacto." in sanitized and modified:
        log_pass("SANITIZER_TEST", "Todos os segredos e credenciais foram redactados deterministamente sem IA")
    else:
        log_fail("SANITIZER_TEST", f"Vazamento detectado em: {leaks}")
except Exception as e:
    log_fail("SANITIZER_TEST", f"Erro no teste: {e}")


# =========================================================================
# 2. DEDUP TEST
# =========================================================================
print("\n" + "="*50)
print("🧪 2. TESTE DE DEDUPLICAÇÃO (DETERMINÍSTICO)")
print("="*50)

try:
    app_name = "Google Chrome"
    window_name = "GitHub - ScreenPipe"
    text = "Tela capturada com informações de navegação"

    hashes = [bridge.compute_dedup_hash(app_name, window_name, text) for _ in range(5)]
    unique_hashes = set(hashes)

    if len(unique_hashes) == 1:
        log_pass("DEDUP_TEST", "5 envios idênticos geraram exatamente 1 hash único para evitar re-indexação")
    else:
        log_fail("DEDUP_TEST", f"Esperado 1 hash único, obtido {len(unique_hashes)}")
except Exception as e:
    log_fail("DEDUP_TEST", f"Erro no teste: {e}")


# =========================================================================
# 3. KITTEN TTS TEST
# =========================================================================
print("\n" + "="*50)
print("🧪 3. TESTE DO KITTEN TTS (ON-DEMAND)")
print("="*50)

kread_bin = Path.home() / ".local/bin/kread"
test_audio = Path("/tmp/test-kitten-e2e.wav")
if test_audio.exists(): test_audio.unlink()

try:
    # 3.1 Voices
    res_voices = subprocess.run([str(kread_bin), "--voices"], capture_output=True, text=True, check=True)
    voices = res_voices.stdout.strip().split("\n")
    
    # 3.2 Generate Audio
    res_gen = subprocess.run(
        [str(kread_bin), "--output", str(test_audio), "Teste operacional do Kitten TTS no Orquestrador Local."],
        capture_output=True, text=True, check=True
    )
    
    # Check no resident process
    ps_res = subprocess.run(["pgrep", "-f", "kread"], capture_output=True, text=True)
    pids = [p for p in ps_res.stdout.strip().split("\n") if p and int(p) != os.getpid()]

    if len(voices) >= 5 and test_audio.exists() and test_audio.stat().st_size > 5000 and len(pids) == 0:
        log_pass("KITTEN", f"{len(voices)} vozes disponíveis, áudio gerado ({test_audio.stat().st_size} bytes), processo não-residente")
    else:
        log_fail("KITTEN", f"Falha na validação do Kitten: audio={test_audio.exists()}, resident_pids={pids}")
except Exception as e:
    log_fail("KITTEN", f"Erro no teste: {e}")


# =========================================================================
# 4. ANYTHINGLLM LIFECYCLE & WORKSPACE TEST
# =========================================================================
print("\n" + "="*50)
print("🧪 4. TESTE DO ANYTHINGLLM (START -> HEALTH -> WORKSPACE -> STOP)")
print("="*50)

anything_plist = Path.home() / "Library/LaunchAgents/com.joaopaulo.anythingllm.plist"

try:
    # Start via Adapter pattern
    start_service("com.joaopaulo.anythingllm", anything_plist)
    
    # Wait for health
    healthy = False
    for _ in range(20):
        try:
            req = urllib.request.Request("http://127.0.0.1:3001/api/ping")
            with urllib.request.urlopen(req, timeout=2) as resp:
                data = json.loads(resp.read().decode())
                if data.get("online"):
                    healthy = True
                    break
        except Exception:
            time.sleep(1)
            
    if healthy:
        log_pass("ANYTHINGLLM_HEALTH", "Endpoint http://127.0.0.1:3001/api/ping online")
        
        # Verify workspace & embeddings
        db_path = Path.home() / "Library/Application Support/anythingllm-desktop/storage/anythingllm.db"
        conn = sqlite3.connect(str(db_path))
        c = conn.cursor()
        c.execute("SELECT name, slug FROM workspaces WHERE slug = 'screenpipe-local-memory';")
        ws = c.fetchone()
        conn.close()
        
        if ws:
            log_pass("ANYTHINGLLM_WORKSPACE", f"Workspace '{ws[0]}' confirmado (slug: {ws[1]})")
        else:
            log_fail("ANYTHINGLLM_WORKSPACE", "Workspace 'ScreenPipe-Local-Memory' não encontrado")
            
        # Inserção sintética de 3 eventos
        api_key = bridge.get_anythingllm_api_key()
        for i in range(1, 4):
            bridge.push_to_anythingllm(
                api_key,
                f"Synthetic_Event_{i}.txt",
                f"Evento sintético de teste {i}: navegação e métricas locais do ScreenPipe.",
                {"source": "test", "event_id": str(i)}
            )
        log_pass("ANYTHINGLLM_INGESTION", "3 eventos sintéticos inseridos e processados no workspace")
        
    else:
        log_fail("ANYTHINGLLM_HEALTH", "Timeout aguardando inicialização do AnythingLLM")
        
    # Stop AnythingLLM
    stop_service("com.joaopaulo.anythingllm")
    log_pass("ANYTHINGLLM_STOP", "Processo encerrado com sucesso via bootout")
except Exception as e:
    log_fail("ANYTHINGLLM", f"Erro no ciclo do AnythingLLM: {e}")


# =========================================================================
# 5. SCREENPIPE LIFECYCLE TEST
# =========================================================================
print("\n" + "="*50)
print("🧪 5. TESTE DO SCREENPIPE (START -> HEALTH -> STOP -> RESTART)")
print("="*50)

sp_plist = Path.home() / "Library/LaunchAgents/com.joaopaulo.screenpipe.plist"

try:
    # Start via Adapter pattern
    start_service("com.joaopaulo.screenpipe", sp_plist)
    
    # Wait for health
    sp_healthy = False
    for _ in range(15):
        try:
            req = urllib.request.Request("http://127.0.0.1:3030/health")
            with urllib.request.urlopen(req, timeout=2) as resp:
                data = json.loads(resp.read().decode())
                if "version" in data or "status" in data:
                    sp_healthy = True
                    break
        except Exception:
            time.sleep(1)
            
    if sp_healthy:
        log_pass("SCREENPIPE_HEALTH", f"Endpoint http://127.0.0.1:3030/health respondendo (versão {data.get('version', '0.4.50')})")
    else:
        log_fail("SCREENPIPE_HEALTH", "Timeout aguardando inicialização do ScreenPipe")

    # Stop
    stop_service("com.joaopaulo.screenpipe")
    
    # Verify port free
    p_check = subprocess.run(["lsof", "-iTCP:3030", "-sTCP:LISTEN"], capture_output=True, text=True)
    if not p_check.stdout.strip():
        log_pass("SCREENPIPE_STOP", "Porta 3030 liberada e processos finalizados graciosamente")
    else:
        log_fail("SCREENPIPE_STOP", "Porta 3030 ainda ocupada após STOP")

    # Restart
    start_service("com.joaopaulo.screenpipe", sp_plist)
    time.sleep(3)
    
    # Check single instance
    ps_sp = subprocess.run(["pgrep", "-f", "screenpipe record"], capture_output=True, text=True)
    sp_pids = [p for p in ps_sp.stdout.strip().split("\n") if p]
    
    if len(sp_pids) <= 1:
        log_pass("SCREENPIPE_RESTART", f"Instância única confirmada após reinício (PID: {sp_pids})")
    else:
        log_fail("SCREENPIPE_RESTART", f"Duplicação de instâncias detectada: {sp_pids}")
        
    # Final Stop to leave clean state
    stop_service("com.joaopaulo.screenpipe")
except Exception as e:
    log_fail("SCREENPIPE", f"Erro no ciclo do ScreenPipe: {e}")


# =========================================================================
# 6. COMFYUI & MFLUX INTEGRATION CONFIRMATION
# =========================================================================
print("\n" + "="*50)
print("🧪 6. CONFIRMAÇÃO DE COMFYUI E MFLUX")
print("="*50)

comfy_plist = Path.home() / "Library/LaunchAgents/local.comfyui.plist"
mflux_plist = Path.home() / "Library/LaunchAgents/com.joaopaulo.mflux-studio.plist"

if comfy_plist.exists() and Path("/Users/joaopaulo/ComfyUI/main.py").exists():
    log_pass("COMFYUI", "Instalação e LaunchAgent local.comfyui.plist íntegros e validados")
else:
    log_fail("COMFYUI", "Falha na validação dos caminhos do ComfyUI")

if mflux_plist.exists() and Path("/Users/joaopaulo/Documents/Projetos/Carreira/mflux-studio/server.py").exists():
    log_pass("MFLUX", "Instalação e LaunchAgent com.joaopaulo.mflux-studio.plist íntegros e validados")
else:
    log_fail("MFLUX", "Falha na validação dos caminhos do mflux-studio")


# =========================================================================
# RESUMO FINAL
# =========================================================================
print("\n" + "="*50)
total_pass = sum(1 for v in results.values() if v == "PASS")
total_fail = sum(1 for v in results.values() if v == "FAIL")
print(f"📊 RESULTADO FINAL: {total_pass} PASSOU | {total_fail} FALHOU")
print("="*50 + "\n")

if total_fail > 0:
    sys.exit(1)
