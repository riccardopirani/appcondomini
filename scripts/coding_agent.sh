#!/bin/bash
# Coding agent interattivo: LLM locale (Ollama) o remoto, con conferma sulle modifiche.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${SCRIPT_DIR}/coding_agent_lib.py"
ENV_FILE="${SCRIPT_DIR}/coding_agent.env"
ENV_EXAMPLE="${SCRIPT_DIR}/coding_agent.env.example"

PROVIDER=""
MODEL=""
TASK=""
FILES=()
DRY_RUN=0
LIST_MODELS=0

usage() {
  cat <<'EOF'
Uso: ./scripts/coding_agent.sh [opzioni]

Coding agent per il progetto Flutter con conferma prima di ogni modifica.

Opzioni:
  -p, --provider <nome>   ollama | openai | anthropic | custom
  -m, --model <nome>      Modello LLM (es. qwen2.5-coder:7b, gpt-4o-mini)
  -t, --task <testo>      Task da eseguire (se omesso, viene chiesto)
  -f, --file <path>       File di contesto (ripetibile, es. lib/main.dart)
  -l, --list-models       Elenca modelli Ollama disponibili
  -n, --dry-run           Mostra solo provider/modello selezionati, senza chiamare l'LLM
  -h, --help              Mostra questo messaggio

Configurazione:
  Copia scripts/coding_agent.env.example in scripts/coding_agent.env
  e imposta API key / URL per i provider remoti.

Esempi:
  ./scripts/coding_agent.sh
  ./scripts/coding_agent.sh -p ollama -m qwen2.5-coder:7b -t "Aggiungi validazione email nel login"
  ./scripts/coding_agent.sh -p openai -m gpt-4o-mini -f lib/main.dart -t "Refactor fetch utenti"
  ./scripts/coding_agent.sh -l

EOF
}

die() {
  echo "Errore: $*" >&2
  exit 1
}

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    set -a
    source "$ENV_FILE"
    set +a
  fi
}

require_python() {
  if ! command -v python3 >/dev/null 2>&1; then
    die "python3 non trovato nel PATH."
  fi
  if [[ ! -f "$LIB" ]]; then
    die "Manca $LIB"
  fi
}

check_project() {
  if [[ ! -f "$ROOT_DIR/pubspec.yaml" ]]; then
    die "pubspec.yaml non trovato. Esegui lo script dalla root del progetto Flutter."
  fi
}

select_provider() {
  if [[ -n "$PROVIDER" ]]; then
    return
  fi

  local default="${CODING_AGENT_PROVIDER:-ollama}"
  echo
  echo "Seleziona provider LLM:"
  echo "  1) ollama      (locale, consigliato)"
  echo "  2) openai      (remoto)"
  echo "  3) anthropic   (remoto)"
  echo "  4) custom      (API OpenAI-compatible: LM Studio, vLLM, OpenRouter...)"
  echo
  read -r -p "Scelta [1-4, default=${default}]: " choice

  case "${choice:-}" in
    ""|1) PROVIDER="ollama" ;;
    2) PROVIDER="openai" ;;
    3) PROVIDER="anthropic" ;;
    4) PROVIDER="custom" ;;
    ollama|openai|anthropic|custom) PROVIDER="$choice" ;;
    *) die "Scelta provider non valida." ;;
  esac
}

select_model() {
  if [[ -n "$MODEL" ]]; then
    return
  fi

  if [[ "$PROVIDER" == "ollama" ]]; then
    local models_json models
    models_json="$(CODING_AGENT_PROVIDER=ollama python3 "$LIB" "$ROOT_DIR" list-ollama-models 2>/dev/null || echo '[]')"
    models="$(python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)))' <<<"$models_json")"

    if [[ -n "$models" ]]; then
      echo
      echo "Modelli Ollama disponibili:"
      local i=1
      while IFS= read -r m; do
        [[ -z "$m" ]] && continue
        echo "  $i) $m"
        i=$((i + 1))
      done <<<"$models"
      echo
      read -r -p "Scegli numero modello o scrivi il nome [default=${CODING_AGENT_MODEL:-primo disponibile}]: " model_choice

      if [[ -z "${model_choice:-}" && -n "${CODING_AGENT_MODEL:-}" ]]; then
        MODEL="$CODING_AGENT_MODEL"
        return
      fi

      if [[ "${model_choice:-}" =~ ^[0-9]+$ ]]; then
        MODEL="$(sed -n "${model_choice}p" <<<"$models")"
        [[ -n "$MODEL" ]] || die "Numero modello non valido."
        return
      fi

      if [[ -n "${model_choice:-}" ]]; then
        MODEL="$model_choice"
        return
      fi

      MODEL="$(head -n 1 <<<"$models")"
      [[ -n "$MODEL" ]] || die "Ollama non risponde o non ci sono modelli. Avvia: ollama serve"
      return
    fi

    read -r -p "Nome modello Ollama [default=${CODING_AGENT_MODEL:-qwen2.5-coder:7b}]: " manual_model
    MODEL="${manual_model:-${CODING_AGENT_MODEL:-qwen2.5-coder:7b}}"
    return
  fi

  case "$PROVIDER" in
    openai)
      MODEL="${CODING_AGENT_MODEL:-gpt-4o-mini}"
      read -r -p "Modello OpenAI [default=${MODEL}]: " manual_model
      MODEL="${manual_model:-$MODEL}"
      ;;
    anthropic)
      MODEL="${CODING_AGENT_MODEL:-claude-sonnet-4-20250514}"
      read -r -p "Modello Anthropic [default=${MODEL}]: " manual_model
      MODEL="${manual_model:-$MODEL}"
      ;;
    custom)
      MODEL="${CODING_AGENT_MODEL:-${CUSTOM_MODEL:-local-model}}"
      read -r -p "Modello custom [default=${MODEL}]: " manual_model
      MODEL="${manual_model:-$MODEL}"
      ;;
  esac
}

prompt_task() {
  if [[ -n "$TASK" ]]; then
    return
  fi

  echo
  echo "Descrivi il task per il coding agent (termina con una riga vuota):"
  local line
  while IFS= read -r line; do
    [[ -z "$line" && -n "$TASK" ]] && break
    if [[ -n "$line" ]]; then
      if [[ -n "$TASK" ]]; then
        TASK+=$'\n'"$line"
      else
        TASK="$line"
      fi
    fi
  done

  [[ -n "$TASK" ]] || die "Task vuoto."
}

confirm_run() {
  echo
  echo "Riepilogo:"
  echo "  Progetto:  $ROOT_DIR"
  echo "  Provider:  $PROVIDER"
  echo "  Modello:   $MODEL"
  if ((${#FILES[@]} > 0)); then
    echo "  File ctx:  ${FILES[*]}"
  fi
  echo "  Task:"
  echo "$TASK" | sed 's/^/    /'
  echo

  read -r -p "Procedere con la chiamata al modello? [S/n]: " ok
  case "${ok:-s}" in
    n|N|no|No) die "Annullato." ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--provider)
      PROVIDER="${2:-}"
      shift 2
      ;;
    -m|--model)
      MODEL="${2:-}"
      shift 2
      ;;
    -t|--task)
      TASK="${2:-}"
      shift 2
      ;;
    -f|--file)
      FILES+=("${2:-}")
      shift 2
      ;;
    -l|--list-models)
      LIST_MODELS=1
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Opzione sconosciuta: $1 (usa -h)"
      ;;
  esac
done

check_project
require_python
load_env

if [[ "$LIST_MODELS" -eq 1 ]]; then
  python3 "$LIB" "$ROOT_DIR" list-ollama-models | python3 -c 'import json,sys; [print(m) for m in json.load(sys.stdin)]'
  exit 0
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Nota: crea $ENV_FILE da $ENV_EXAMPLE per API key e impostazioni persistenti."
fi

select_provider
export CODING_AGENT_PROVIDER="$PROVIDER"
select_model
export CODING_AGENT_MODEL="$MODEL"
prompt_task

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry-run completato."
  exit 0
fi

confirm_run

files_json="[]"
if ((${#FILES[@]} > 0)); then
  files_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${FILES[@]}")"
fi

python3 "$LIB" "$ROOT_DIR" run "$TASK" "$files_json" "$PROVIDER" "$MODEL"
