"""Actual old code with one temporary storage URL; never touches Documents."""
import hashlib,json,os,re,subprocess,tempfile
from pathlib import Path
repo=Path(__file__).resolve().parents[2]
source=repo/'Checklist Manifesto v2'
names=['Models/AppData.swift','Models/Checklist.swift','Models/ChecklistItem.swift','ViewModels/MainViewModel.swift']
with tempfile.TemporaryDirectory(prefix='checklist-red-') as d:
 root=Path(d); files=[]
 print(json.dumps({'source_hashes':{n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in names}}),flush=True)
 for name in names:
  text=(source/name).read_text()
  if name=='Models/AppData.swift':
   text,count=re.subn(r'    static let fileURL: URL = \{.*?\n    \}\(\)', '    static let fileURL: URL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CHECKLIST_TEST_FILE"]!)',text,flags=re.S)
   assert count==1 and '.documentDirectory' not in text
  p=root/Path(name).name;p.write_text(text);files.append(str(p))
 subprocess.run(['xcrun','swiftc','-swift-version','5','-module-cache-path',str(root/'cache'),*files,str(repo/'tests/SafeStorage/baseline.swift'),'-o',str(root/'probe')],check=True,timeout=90)
 run=subprocess.run([str(root/'probe')],env={**os.environ,'CHECKLIST_TEST_FILE':str(root/'checklists.json')},timeout=20)
 raise SystemExit(run.returncode)
