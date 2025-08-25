import base64
import json
import time
from typing import Dict, Any

def run_workflow(comfy_worker, workflow: Dict[str, Any]) -> Dict[str, Any]:
    """
    Exécute un workflow ComfyUI et retourne les résultats.
    """
    try:
        # Valider le workflow
        if not workflow or not isinstance(workflow, dict):
            return {"error": "Invalid workflow format"}
        
        # Exécuter le workflow
        output_images = comfy_worker.run_workflow(workflow)
        
        # Convertir les images en base64
        encoded_images = []
        for img_data in output_images:
            if isinstance(img_data, bytes):
                encoded_images.append(base64.b64encode(img_data).decode('utf-8'))
            else:
                encoded_images.append(img_data)
        
        return {
            "images": encoded_images,
            "message": "Workflow executed successfully"
        }
        
    except Exception as e:
        return {"error": f"Workflow execution failed: {str(e)}"}
