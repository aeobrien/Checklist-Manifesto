"""Build maintained iOS callers for a generic destination; never launch or install."""
import subprocess,tempfile
from pathlib import Path
repo=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='checklist-safe-storage-ios-') as d:
 result=subprocess.run(['xcodebuild','-quiet','-project',str(repo/'Checklist Manifesto v2.xcodeproj'),'-scheme','Checklist Manifesto v2','-sdk','iphonesimulator','-destination','generic/platform=iOS Simulator','-derivedDataPath',d,'CODE_SIGNING_ALLOWED=NO','build'],cwd=repo,timeout=240)
 raise SystemExit(result.returncode)
