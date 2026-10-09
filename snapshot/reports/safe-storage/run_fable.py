"""Transmit only the exact prepared review package through the maintained client."""
import hashlib
import json
import shlex
import subprocess
import sys
from pathlib import Path
sys.path.insert(0, '/Users/aidan/.claude/lib')
from openrouter_client import OpenRouterClient
root = Path(__file__).resolve().parents[2]
raw = (root/'reports/safe-storage/fable-disclosure-02/payload.json').read_bytes()
assert hashlib.sha256(raw).hexdigest() == 'e64463c92f91f4cfcf97f515122a8e87c02bf8b87cd962f3bf61bab04b4d49be'
payload = json.loads(raw)
assert payload['model'] == 'anthropic/claude-fable-5.1' and payload['budget_usd'] == 3
out = root/'reports/safe-storage/reviews/fable-01'
out.mkdir(parents=True, exist_ok=False)
# Resolve the configured credential in memory only; never include it in evidence.
key = subprocess.run(['zsh','-c','source '+shlex.quote(str(Path.home()/'.zshrc'))+' >/dev/null 2>&1; printf \'%s\' "$OPENROUTER_API_KEY"'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,timeout=30)
if key.returncode or not key.stdout.strip():
    raise RuntimeError('Configured credential source returned no credential')
r = OpenRouterClient(logs_dir=out/'raw', budget_usd=payload['budget_usd'], api_key=key.stdout.strip()).call(model=payload['model'],system=payload['system'],user=payload['user'],max_tokens=payload['max_tokens'],reasoning=payload['reasoning'],temperature=payload['temperature'],read_timeout_s=payload['read_timeout_s'])
(out/'review.md').write_text(r.response_text+'\n')
(out/'receipt.json').write_text(json.dumps({'model':payload['model'],'payload_sha256':hashlib.sha256(raw).hexdigest(),'executed_tests':False,'visible_review':bool(r.response_text.strip())},indent=2)+'\n')
print(r.response_text or 'INCOMPLETE: no visible review')
