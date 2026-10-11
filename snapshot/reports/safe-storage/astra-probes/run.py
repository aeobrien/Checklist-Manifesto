import hashlib, json, subprocess, tempfile
from pathlib import Path
repo=Path(__file__).resolve().parents[3]
source=repo/'Checklist Manifesto v2'
names=['Models/AppData.swift','Models/Checklist.swift','Models/ChecklistItem.swift','ViewModels/MainViewModel.swift']
with tempfile.TemporaryDirectory(prefix='checklist-astra-') as d:
    temp=Path(d)
    print(json.dumps({'source_sha256':{n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in names}}),flush=True)
    subprocess.run(['xcrun','swiftc','-swift-version','5','-module-cache-path',str(temp/'cache'),*[str(source/n) for n in names],str(Path(__file__).with_name('Checks.swift')),'-o',str(temp/'checks')],check=True,timeout=90)
    subprocess.run([str(temp/'checks'),str(temp)],check=True,timeout=30)
