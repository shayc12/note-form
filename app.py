import json
from pathlib import Path
from uuid import uuid4
from flask import Flask, jsonify, render_template_string, request
app = Flask(__name__)
FORM = """<!doctype html><title>Workshop Notes</title><h1>Workshop Notes</h1><form method="post" action="/notes"><p><input name="title" placeholder="Title" required></p><p><textarea name="content" placeholder="Your note" required></textarea></p><button type="submit">Save note</button></form>"""
def save_note(note):
    key = f"notes/{uuid4().hex}.json"
    path = Path(key)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(note, ensure_ascii=False), encoding="utf-8")
    return key
@app.get("/")
def index():
    return render_template_string(FORM)
@app.get("/health")
def health():
    return {"status": "ok"}
@app.post("/notes")
def create_note():
    title = request.form.get("title", "").strip()
    content = request.form.get("content", "").strip()
    if not title or not content:
        return {"error": "Title and content are required"}, 400
    if len(title) > 100 or len(content) > 5000:
        return {"error": "Note is too long"}, 400
    try:
        key = save_note({"title": title, "content": content})
    except Exception:
        app.logger.exception("Could not save note")
        return {"error": "Could not save note"}, 500
    return jsonify(message="Note saved", key=key), 201
