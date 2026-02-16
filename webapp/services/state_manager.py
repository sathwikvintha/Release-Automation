import json
import os

STATE_FILE = "pipeline_state.json"

DEFAULT_STATE = {
    "angular": "IDLE",
    "incrementals": "IDLE",
    "commit": "IDLE",
    "report": "IDLE",
    "attach": "IDLE",
    "security": "IDLE",
    "staas": "IDLE",
    "zip": "IDLE",
    "email": "IDLE"
}

def init_state():
    with open(STATE_FILE, "w") as f:
        json.dump(DEFAULT_STATE, f)

def get_state():
    if not os.path.exists(STATE_FILE):
        return DEFAULT_STATE
    with open(STATE_FILE, "r") as f:
        return json.load(f)

def update_step_status(step, status):
    state = get_state()
    state[step] = status
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)
