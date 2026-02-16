import threading
import os
from fastapi import FastAPI, Body
from fastapi.responses import JSONResponse, HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from services.state_manager import init_state, get_state
from services.pipeline_runner import run_step

app = FastAPI()

app.mount("/static", StaticFiles(directory="static"), name="static")

init_state()

@app.get("/", response_class=HTMLResponse)
def dashboard():
    with open("templates/dashboard.html", "r", encoding="utf-8") as f:
        return f.read()
    
@app.get("/staas", response_class=HTMLResponse)
def staas_page():
    with open("templates/staas.html", "r", encoding="utf-8") as f:
        return f.read()

@app.get("/status")
def status():
    return JSONResponse(get_state())

@app.post("/run/{step_name}")
def run_pipeline_step(step_name: str, inputs: dict = Body(default={})):
    thread = threading.Thread(target=run_step, args=(step_name, inputs))
    thread.start()
    return {"message": f"{step_name} started"}

@app.get("/logs/{step_name}")
def get_logs(step_name: str):
    log_path = f"logs/{step_name}.log"
    if not os.path.exists(log_path):
        return {"logs": ""}
    with open(log_path, "r", encoding="utf-8") as f:
        return {"logs": f.read()}

@app.get("/json-files")
def get_json_files():
    BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../"))
    folder = os.path.join(BASE_DIR, "python", "release-report-generator", "json_files")
    files = [f for f in os.listdir(folder) if f.endswith(".json")]
    return files

@app.get("/download/{filename}")
def download_file(filename: str):
    path = f"../python/release-report-generator/output/{filename}"
    return FileResponse(path, filename=filename)
