import runpod
import aiohttp
import asyncio
import json
import urllib.parse

async def async_handler(job):
    """
    Handler asynchrone pour traiter les jobs RunPod
    """
    job_input = job['input']
    workflow = job_input.get('workflow', {})
    
    # URL de l'API ComfyUI
    comfyui_url = "http://localhost:8188"
    
    try:
        # 1. Envoyer le workflow à ComfyUI
        async with aiohttp.ClientSession() as session:
            # API pour envoyer le prompt
            prompt_url = f"{comfyui_url}/prompt"
            async with session.post(prompt_url, json={"prompt": workflow}) as response:
                if response.status != 200:
                    error_text = await response.text()
                    return {"error": f"Erreur ComfyUI: {error_text}"}
                
                result = await response.json()
                prompt_id = result['prompt_id']
            
            # 2. Attendre la fin de l'exécution
            history_url = f"{comfyui_url}/history"
            max_attempts = 300  # 5 minutes max (1s par tentative)
            
            for attempt in range(max_attempts):
                await asyncio.sleep(1)  # Attendre 1 seconde
                
                async with session.get(history_url) as history_response:
                    if history_response.status == 200:
                        history = await history_response.json()
                        if prompt_id in history:
                            # Exécution terminée
                            output = history[prompt_id]
                            
                            # 3. Récupérer les images générées
                            outputs = output.get('outputs', {})
                            images = []
                            
                            for node_id, node_output in outputs.items():
                                if 'images' in node_output:
                                    for image in node_output['images']:
                                        image_url = f"{comfyui_url}/view?filename={urllib.parse.quote(image['filename']}&subfolder={urllib.parse.quote(image.get('subfolder', ''))}&type={image.get('type', 'output')}"
                                        images.append({
                                            "url": image_url,
                                            "filename": image['filename'],
                                            "subfolder": image.get('subfolder', ''),
                                            "type": image.get('type', 'output')
                                        })
                            
                            return {
                                "status": "completed",
                                "prompt_id": prompt_id,
                                "images": images,
                                "outputs": outputs
                            }
            
            return {"error": "Timeout: Le traitement a pris trop de temps"}
    
    except Exception as e:
        return {"error": f"Erreur inattendue: {str(e)}"}

def handler(job):
    """
    Handler principal pour RunPod
    """
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    result = loop.run_until_complete(async_handler(job))
    loop.close()
    return result

# Démarrer le serveur RunPod
runpod.serverless.start({"handler": handler})
