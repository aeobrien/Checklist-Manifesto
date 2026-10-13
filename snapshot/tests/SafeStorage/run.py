"""Compile actual maintained storage/models/viewmodel, only synthetic injected URLs."""
import hashlib,json,subprocess,tempfile
from pathlib import Path
repo=Path(__file__).resolve().parents[2];source=repo/'Checklist Manifesto v2'
names=['Models/AppData.swift','Models/Checklist.swift','Models/ChecklistItem.swift','ViewModels/MainViewModel.swift','ViewModels/ChecklistViewModel.swift']
with tempfile.TemporaryDirectory(prefix='checklist-safe-storage-') as d:
 root=Path(d)
 print(json.dumps({'source_hashes':{n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in names}}),flush=True)
 subprocess.run(['xcrun','swiftc','-swift-version','5','-module-cache-path',str(root/'cache'),*[str(source/n) for n in names],str(repo/'tests/SafeStorage/Checks.swift'),'-o',str(root/'checks')],check=True,timeout=90)
 result=subprocess.run([str(root/'checks'),str(root)],timeout=30)
 raise SystemExit(result.returncode)
