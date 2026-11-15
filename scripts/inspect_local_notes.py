import json
from pathlib import Path
for path in sorted(Path("notes").glob("*.json")):
    note = json.loads(path.read_text())
    print(path.name, note["title"], note.get("category", "general"))
