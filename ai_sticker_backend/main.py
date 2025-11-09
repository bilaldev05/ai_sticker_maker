from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import FileResponse
from pathlib import Path
from PIL import Image
import io
import torch
from diffusers import StableDiffusionPipeline, DPMSolverMultistepScheduler
from diffusers.loaders import LoraLoaderMixin
import numpy as np

app = FastAPI(title="AI Sticker Generator")

# Output folder for stickers
OUTPUT_DIR = Path("generated_stickers")
OUTPUT_DIR.mkdir(exist_ok=True)

# -------------------------------
# Load Stable Diffusion base model + LoRA adapter
# -------------------------------
MODEL_BASE = "runwayml/stable-diffusion-v1-5"
LORA_ADAPTER = Path("artificialguybr_stickers-redmond-1-5.safetensors")  # local LoRA file

print("Loading Stable Diffusion pipeline... this may take a while.")
pipe = StableDiffusionPipeline.from_pretrained(
    MODEL_BASE,
    torch_dtype=torch.float16,
    use_auth_token=True  # Replace with your Hugging Face token if needed
)

# Apply LoRA adapter
LoraLoaderMixin.load_lora_weights(pipe.unet, LORA_ADAPTER, weight=1.0)
pipe.set_scheduler(DPMSolverMultistepScheduler.from_config(pipe.scheduler.config))
pipe = pipe.to("cuda") if torch.cuda.is_available() else pipe.to("cpu")
print("Model loaded successfully!")

# -------------------------------
# Helper function: make transparent background
# -------------------------------
def make_transparent(img: Image.Image, bg_color=(255, 255, 255)) -> Image.Image:
    """
    Convert white (or specified bg_color) background to transparent
    """
    img = img.convert("RGBA")
    data = np.array(img)
    r, g, b, a = data.T
    mask = (r == bg_color[0]) & (g == bg_color[1]) & (b == bg_color[2])
    data[..., 3][mask] = 0
    return Image.fromarray(data)

# -------------------------------
# Routes
# -------------------------------
@app.get("/")
def home():
    return {"message": "Welcome to the AI Sticker Generator API"}

# Text → Sticker
@app.post("/generate_sticker")
async def generate_sticker(text: str = Form(...)):
    """
    Takes text input and generates a 512x512 sticker PNG
    """
    prompt = f"{text}, cartoon style, bright colors, sticker, bold outlines, flat colors, vector style"
    
    # Generate image
    image = pipe(prompt, height=512, width=512).images[0]

    # Make background transparent (assumes white bg)
    image_transparent = make_transparent(image)

    # Save file
    file_path = OUTPUT_DIR / "generated_sticker.png"
    image_transparent.save(file_path)

    return FileResponse(file_path, media_type="image/png")

# Image Upload → Sticker
@app.post("/upload_image")
async def upload_image(image: UploadFile = File(...)):
    """
    Accepts an uploaded image, removes background, resizes to 512x512
    """
    img = Image.open(io.BytesIO(await image.read())).convert("RGBA")

    # Make background transparent
    img_transparent = make_transparent(img)

    # Resize to 512x512
    img_resized = img_transparent.resize((512, 512))
    file_path = OUTPUT_DIR / f"uploaded_{image.filename}"
    img_resized.save(file_path)

    return FileResponse(file_path, media_type="image/png")



# py -m uvicorn main:app --reload  