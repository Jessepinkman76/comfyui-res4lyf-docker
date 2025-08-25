import runpod
from runpod import RunPodLogger
import requests
import time
import json

# Configuration du logger
log = RunPodLogger()

def handler(job):
    """
    Handler principal pour traiter les jobs RunPod
    """
    try:
        job_input = job['input']
        workflow = job_input.get('workflow', {})
        
        log.info("Traitement du workflow ComfyUI")
        
        # Envoyer le workflow à ComfyUI
        response = requests.post(
            "http://localhost:8188/prompt",
            json={"prompt": workflow},
            timeout=30
        )
        response.raise_for_status()
        
        prompt_id = response.json()["prompt_id"]
        log.info(f"Prompt ID: {prompt_id}")
        
        # Attendre la completion
        max_attempts = 300
        for attempt in range(max_attempts):
            time.sleep(1)
            
            history_response = requests.get("http://localhost:8188/history")
            history_response.raise_for_status()
            
            history = history_response.json()
            if prompt_id in history:
                log.info("Traitement terminé avec succès")
                return {
                    "status": "success",
                    "prompt_id": prompt_id,
                    "result": history[prompt_id]
                }
        
        return {"error": "Timeout: Le traitement a pris trop de temps"}
        
    except requests.exceptions.RequestException as e:
        log.error(f"Erreur de connexion: {str(e)}")
        return {"error": f"Erreur de connexion: {str(e)}"}
    except json.JSONDecodeError as e:
        log.error(f"Erreur JSON: {str(e)}")
        return {"error": f"Erreur JSON: {str(e)}"}
    except Exception as e:
        log.error(f"Erreur inattendue: {str(e)}")
        return {"error": f"Erreur inattendue: {str(e)}"}

# Démarrer le serveur RunPod
if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
