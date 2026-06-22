#!/usr/bin/env python3
"""Helper per coding_agent.sh: chiamate LLM, parsing risposta, diff e apply."""

from __future__ import annotations

import difflib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

FILE_BLOCK_RE = re.compile(
    r"<<<FILE\s+path=(?P<path>[^>]+)>>>\s*\n(?P<content>.*?)<<<END_FILE>>>",
    re.DOTALL,
)

IGNORE_DIRS = {
    ".git",
    ".dart_tool",
    "build",
    "ios/Pods",
    "ios/build",
    "android/.gradle",
    "node_modules",
    "backend-email/node_modules",
    ".idea",
}


def load_env_file(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    if not path.is_file():
        return env
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def merge_config(root: Path) -> dict[str, str]:
    cfg = {
        "CODING_AGENT_PROVIDER": os.environ.get("CODING_AGENT_PROVIDER", "ollama"),
        "CODING_AGENT_MODEL": os.environ.get("CODING_AGENT_MODEL", ""),
        "OLLAMA_BASE_URL": os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434"),
        "OPENAI_API_KEY": os.environ.get("OPENAI_API_KEY", ""),
        "OPENAI_BASE_URL": os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1"),
        "ANTHROPIC_API_KEY": os.environ.get("ANTHROPIC_API_KEY", ""),
        "CUSTOM_BASE_URL": os.environ.get("CUSTOM_BASE_URL", ""),
        "CUSTOM_API_KEY": os.environ.get("CUSTOM_API_KEY", ""),
        "CUSTOM_MODEL": os.environ.get("CUSTOM_MODEL", ""),
        "CODING_AGENT_MAX_CONTEXT_FILES": os.environ.get("CODING_AGENT_MAX_CONTEXT_FILES", "25"),
        "CODING_AGENT_MAX_FILE_BYTES": os.environ.get("CODING_AGENT_MAX_FILE_BYTES", "60000"),
    }
    env_path = root / "scripts" / "coding_agent.env"
    cfg.update(load_env_file(env_path))
    for key, value in os.environ.items():
        if key.startswith(
            (
                "CODING_AGENT_",
                "OLLAMA_",
                "OPENAI_",
                "ANTHROPIC_",
                "CUSTOM_",
            )
        ):
            cfg[key] = value
    return cfg


def http_json(
    url: str,
    payload: dict[str, Any],
    headers: dict[str, str] | None = None,
    timeout: int = 300,
) -> dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json", **(headers or {})},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def http_get_json(url: str, timeout: int = 30) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def list_ollama_models(base_url: str) -> list[str]:
    try:
        data = http_get_json(f"{base_url.rstrip('/')}/api/tags")
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return []
    models = []
    for item in data.get("models", []):
        name = item.get("name")
        if name:
            models.append(name)
    return models


def build_system_prompt(root: Path) -> str:
    return f"""You are a coding agent for a Flutter/Dart project at {root}.
Respond ONLY with file blocks for files you want to create or fully replace.
Do not explain outside the blocks. Use this exact format for each file:

<<<FILE path=relative/path/from/project/root>>>
full file content here
<<<END_FILE>>>

Rules:
- Use paths relative to the project root (e.g. lib/main.dart).
- Output complete file contents, not partial snippets or diffs.
- Only include files that must change to fulfill the task.
- Preserve existing style and conventions when editing.
- If no code changes are needed, reply with exactly: NO_CHANGES
"""


def collect_project_tree(root: Path, max_depth: int = 4) -> str:
    lines: list[str] = []

    def walk(dir_path: Path, depth: int) -> None:
        if depth > max_depth:
            return
        try:
            entries = sorted(dir_path.iterdir(), key=lambda p: (p.is_file(), p.name.lower()))
        except OSError:
            return
        for entry in entries:
            rel = entry.relative_to(root).as_posix()
            if any(part in IGNORE_DIRS for part in entry.parts):
                continue
            if entry.name.startswith(".") and entry.name not in {".gitignore"}:
                continue
            prefix = "  " * depth
            if entry.is_dir():
                lines.append(f"{prefix}{rel}/")
                walk(entry, depth + 1)
            else:
                lines.append(f"{prefix}{rel}")

    walk(root, 0)
    return "\n".join(lines[:400])


def read_context_files(
    root: Path,
    explicit_files: list[str],
    max_files: int,
    max_bytes: int,
) -> str:
    chunks: list[str] = []
    seen: set[str] = set()

    def add_file(rel: str) -> None:
        if rel in seen or len(seen) >= max_files:
            return
        path = (root / rel).resolve()
        try:
            path.relative_to(root.resolve())
        except ValueError:
            return
        if not path.is_file():
            return
        try:
            content = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            return
        if len(content.encode("utf-8")) > max_bytes:
            content = content[: max_bytes // 2] + "\n\n... [troncato per limite contesto] ...\n"
        seen.add(rel)
        chunks.append(f"--- {rel} ---\n{content}\n")

    for rel in explicit_files:
        add_file(rel.strip().lstrip("/"))

    if not explicit_files:
        defaults = [
            "pubspec.yaml",
            "lib/main.dart",
            "lib/services/api_service.dart",
            "analysis_options.yaml",
        ]
        for rel in defaults:
            add_file(rel)

    return "\n".join(chunks)


def call_llm(cfg: dict[str, str], system: str, user: str) -> str:
    provider = cfg.get("CODING_AGENT_PROVIDER", "ollama").lower()
    model = cfg.get("CODING_AGENT_MODEL", "").strip()

    if provider == "ollama":
        if not model:
            models = list_ollama_models(cfg["OLLAMA_BASE_URL"])
            if not models:
                raise RuntimeError("Nessun modello Ollama disponibile. Avvia Ollama e scarica un modello.")
            model = models[0]
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "stream": False,
        }
        data = http_json(f"{cfg['OLLAMA_BASE_URL'].rstrip('/')}/api/chat", payload, timeout=600)
        return data.get("message", {}).get("content", "")

    if provider == "openai":
        api_key = cfg.get("OPENAI_API_KEY", "")
        if not api_key:
            raise RuntimeError("OPENAI_API_KEY mancante in coding_agent.env")
        if not model:
            model = "gpt-4o-mini"
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "temperature": 0.2,
        }
        data = http_json(
            f"{cfg['OPENAI_BASE_URL'].rstrip('/')}/chat/completions",
            payload,
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=600,
        )
        return data["choices"][0]["message"]["content"]

    if provider == "anthropic":
        api_key = cfg.get("ANTHROPIC_API_KEY", "")
        if not api_key:
            raise RuntimeError("ANTHROPIC_API_KEY mancante in coding_agent.env")
        if not model:
            model = "claude-sonnet-4-20250514"
        payload = {
            "model": model,
            "max_tokens": 8192,
            "system": system,
            "messages": [{"role": "user", "content": user}],
        }
        data = http_json(
            "https://api.anthropic.com/v1/messages",
            payload,
            headers={
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
            },
            timeout=600,
        )
        parts = data.get("content", [])
        return "".join(part.get("text", "") for part in parts if part.get("type") == "text")

    if provider == "custom":
        base = cfg.get("CUSTOM_BASE_URL", "").rstrip("/")
        if not base:
            raise RuntimeError("CUSTOM_BASE_URL mancante in coding_agent.env")
        if not model:
            model = cfg.get("CUSTOM_MODEL", "") or "local-model"
        api_key = cfg.get("CUSTOM_API_KEY", "not-needed")
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "temperature": 0.2,
        }
        data = http_json(
            f"{base}/chat/completions",
            payload,
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=600,
        )
        return data["choices"][0]["message"]["content"]

    raise RuntimeError(f"Provider sconosciuto: {provider}")


def parse_file_blocks(text: str) -> list[tuple[str, str]]:
    if "NO_CHANGES" in text.strip():
        return []
    blocks: list[tuple[str, str]] = []
    for match in FILE_BLOCK_RE.finditer(text):
        path = match.group("path").strip()
        content = match.group("content")
        if content.endswith("\n"):
            content = content[:-1]
        blocks.append((path, content))
    return blocks


def unified_diff(rel_path: str, old: str, new: str) -> str:
    old_lines = old.splitlines(keepends=True)
    new_lines = new.splitlines(keepends=True)
    diff = difflib.unified_diff(
        old_lines,
        new_lines,
        fromfile=f"a/{rel_path}",
        tofile=f"b/{rel_path}",
        lineterm="",
    )
    return "".join(diff) if diff else f"(nuovo file: {rel_path})\n"


def cmd_list_ollama_models(cfg: dict[str, str]) -> None:
    models = list_ollama_models(cfg["OLLAMA_BASE_URL"])
    print(json.dumps(models))


def cmd_run_agent(
    root: Path,
    task: str,
    files: list[str],
    provider: str | None,
    model: str | None,
) -> int:
    cfg = merge_config(root)
    if provider:
        cfg["CODING_AGENT_PROVIDER"] = provider
    if model:
        cfg["CODING_AGENT_MODEL"] = model

    max_files = int(cfg.get("CODING_AGENT_MAX_CONTEXT_FILES", "25"))
    max_bytes = int(cfg.get("CODING_AGENT_MAX_FILE_BYTES", "60000"))

    system = build_system_prompt(root)
    tree = collect_project_tree(root)
    context = read_context_files(root, files, max_files, max_bytes)
    user = f"""Task:
{task}

Project tree:
{tree}

Relevant files:
{context if context else "(nessun file di contesto letto)"}
"""

    print("==> Chiamata al modello in corso...", flush=True)
    try:
        response = call_llm(cfg, system, user)
    except Exception as exc:
        print(f"Errore LLM: {exc}", file=sys.stderr)
        return 1

    blocks = parse_file_blocks(response)
    if not blocks:
        print("\nNessuna modifica proposta dal modello.")
        if response.strip():
            print("\n--- Risposta grezza ---")
            print(response[:4000])
        return 0

    backup_dir = root / ".coding_agent_backups"
    backup_dir.mkdir(exist_ok=True)

    applied = 0
    skipped = 0

    for rel_path, new_content in blocks:
        target = (root / rel_path).resolve()
        try:
            target.relative_to(root.resolve())
        except ValueError:
            print(f"\n[SKIP] Percorso non valido: {rel_path}")
            skipped += 1
            continue

        old_content = ""
        if target.is_file():
            old_content = target.read_text(encoding="utf-8")

        if old_content == new_content:
            print(f"\n[SKIP] Nessuna differenza: {rel_path}")
            skipped += 1
            continue

        diff = unified_diff(rel_path, old_content, new_content)
        print("\n" + "=" * 72)
        print(f"File: {rel_path}")
        print("=" * 72)
        print(diff if diff else "(nessun diff)")

        while True:
            choice = input("\nApplicare? [s]ì / [n]o / [q]uit / [a]pplica tutti i restanti: ").strip().lower()
            if choice in {"s", "si", "sì", "y", "yes"}:
                apply = True
                auto_rest = False
                break
            if choice in {"n", "no"}:
                apply = False
                auto_rest = False
                break
            if choice in {"q", "quit", "esci"}:
                print("Interrotto dall'utente.")
                return 0
            if choice in {"a", "all", "tutti"}:
                apply = True
                auto_rest = True
                break
            print("Scelta non valida.")

        if not apply:
            skipped += 1
            continue

        target.parent.mkdir(parents=True, exist_ok=True)
        if target.is_file():
            backup = backup_dir / rel_path.replace("/", "__")
            backup.write_text(old_content, encoding="utf-8")
        target.write_text(new_content, encoding="utf-8")
        print(f"✓ Applicato: {rel_path}")
        applied += 1

        if auto_rest:
            for rest_path, rest_content in blocks[blocks.index((rel_path, new_content)) + 1 :]:
                rest_target = (root / rest_path).resolve()
                try:
                    rest_target.relative_to(root.resolve())
                except ValueError:
                    print(f"[SKIP] Percorso non valido: {rest_path}")
                    skipped += 1
                    continue
                rest_old = ""
                if rest_target.is_file():
                    rest_old = rest_target.read_text(encoding="utf-8")
                if rest_old == rest_content:
                    print(f"[SKIP] Nessuna differenza: {rest_path}")
                    skipped += 1
                    continue
                rest_target.parent.mkdir(parents=True, exist_ok=True)
                if rest_target.is_file():
                    backup = backup_dir / rest_path.replace("/", "__")
                    backup.write_text(rest_old, encoding="utf-8")
                rest_target.write_text(rest_content, encoding="utf-8")
                print(f"✓ Applicato (auto): {rest_path}")
                applied += 1
            break

    print(f"\nFatto. Applicati: {applied}, saltati: {skipped}")
    if applied:
        print(f"Backup in: {backup_dir}")
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print("Uso interno: coding_agent_lib.py <comando> ...", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    command = sys.argv[2]

    if command == "list-ollama-models":
        cfg = merge_config(root)
        cmd_list_ollama_models(cfg)
        return 0

    if command == "run":
        task = sys.argv[3]
        files = json.loads(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else []
        provider = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] != "-" else None
        model = sys.argv[6] if len(sys.argv) > 6 and sys.argv[6] != "-" else None
        return cmd_run_agent(root, task, files, provider, model)

    print(f"Comando sconosciuto: {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
