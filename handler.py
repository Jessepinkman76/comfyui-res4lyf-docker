import runpod
import importlib.util
import sys
import os
import asyncio
from rp_handler import run_workflow

# Configurer le chemin de ComfyUI
COMFYUI_PATH = os.getenv('COMFYUI_PATH', '/home/comfyuser/ComfyUI')
sys.path.append(COMFYUI_PATH)

# Charger les modules de ComfyUI
def load_comfyui_modules():
    try:
        from comfy_worker import ComfyWorker
        return ComfyWorker
    except ImportError:
        # Fallback si le module n'est pas trouvé
        spec = importlib.util.spec_from_file_location("comfy_worker", 
                    os.path.join(COMFYUI_PATH, "comfy_worker.py"))
        if spec and spec.loader:
            comfy_worker = importlib.util.module_from_spec(spec)
            sys.modules["comfy_worker"] = comfy_worker
            spec.loader.exec_module(comfy_worker)
            return comfy_worker.ComfyWorker
        else:
            raise Exception("ComfyWorker module not found")

# Initialiser le worker ComfyUI
try:
    ComfyWorker = load_comfyui_modules()
    comfy_worker = ComfyWorker()
except Exception as e:
    print(f"Error initializing ComfyWorker: {e}")
    comfy_worker = None

def handler(job):
    """
    Gère les jobs RunPod.
    """
    try:
        job_input = job.get('input', {})
        workflow = job_input.get('workflow', {})
        
        if not workflow:
            return {"error": "No workflow provided in input"}
        
        if not comfy_worker:
            return {"error": "ComfyUI worker not initialized"}
        
        # Exécuter le workflow
        results = run_workflow(comfy_worker, workflow)
        
        return {
            "status": "success",
            "output": results
        }
        
    except Exception as e:
        return {
            "status": "error",
            "message": str(e)
        }

# Démarrer le service RunPod
if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
