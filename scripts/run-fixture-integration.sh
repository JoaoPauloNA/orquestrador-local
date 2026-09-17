#!/bin/zsh
# Exercises an isolated user LaunchAgent and removes only the label created here.
set -euo pipefail

project_dir=${0:A:h:h}
uid_value=$(id -u)
token=$(/usr/bin/uuidgen | tr '[:upper:]' '[:lower:]')
label="local.orquestrador.fixture.${token}"
port=$(/usr/bin/python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
work_dir=$(mktemp -d /tmp/orq-fixture.XXXXXX)
plist_path="$HOME/Library/LaunchAgents/${label}.plist"
activity_path="$work_dir/activity.txt"
fixture_path="$work_dir/loopback_service.py"
owns_plist=false
owns_job=false

if [[ -e "$plist_path" ]]; then
  echo 'FALHOU: colisão com plist preexistente; nenhum artefato foi alterado' >&2
  exit 1
fi

cleanup() {
  if [[ "$owns_job" == true ]]; then /bin/launchctl bootout "gui/${uid_value}/${label}" >/dev/null 2>&1 || true; fi
  if [[ "$owns_plist" == true ]]; then /bin/rm -f "$plist_path"; fi
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

printf 'idle\n' > "$activity_path"
/bin/cp "$project_dir/fixtures/loopback_service.py" "$fixture_path"
/usr/bin/plutil -create xml1 "$plist_path"
owns_plist=true
/usr/libexec/PlistBuddy -c "Add :Label string $label" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments array" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments:0 string /usr/bin/python3" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments:1 string $fixture_path" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments:2 string --port" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments:3 string $port" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments:4 string --activity-file" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :ProgramArguments:5 string $activity_path" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :WorkingDirectory string $project_dir" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :RunAtLoad bool false" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :StandardOutPath string $work_dir/fixture.out" "$plist_path"
/usr/libexec/PlistBuddy -c "Add :StandardErrorPath string $work_dir/fixture.err" "$plist_path"

/bin/launchctl bootstrap "gui/${uid_value}" "$plist_path"
owns_job=true
/bin/launchctl kickstart "gui/${uid_value}/${label}"

for attempt in {1..20}; do
  if /usr/bin/curl --noproxy '*' --max-time 1 -fsS "http://127.0.0.1:${port}/health" 2>/dev/null | /usr/bin/grep -q 'orquestrador-fixture'; then break; fi
  /bin/sleep 0.25
done
if ! /usr/bin/curl --noproxy '*' --max-time 2 -fsS "http://127.0.0.1:${port}/health" | /usr/bin/grep -q 'orquestrador-fixture'; then
  echo 'FALHOU: fixture não atingiu prontidão; saída sanitizada:' >&2
  /usr/bin/tail -3 "$work_dir/fixture.err" 2>/dev/null || true
  exit 1
fi
/usr/bin/curl --noproxy '*' --max-time 2 -fsS "http://127.0.0.1:${port}/queue" | /usr/bin/grep -q 'queue_running'
printf 'busy\n' > "$activity_path"
/usr/bin/curl --noproxy '*' --max-time 2 -fsS "http://127.0.0.1:${port}/queue" | /usr/bin/grep -q 'synthetic-job'
/bin/launchctl bootout "gui/${uid_value}/${label}"
for attempt in {1..20}; do
  /bin/launchctl print "gui/${uid_value}/${label}" >/dev/null 2>&1 || { echo 'PASSOU: ciclo fixture start/ready/activity/busy/stop'; exit 0; }
  /bin/sleep 0.25
done
echo 'FALHOU: fixture ainda carregada após bootout' >&2
exit 1
