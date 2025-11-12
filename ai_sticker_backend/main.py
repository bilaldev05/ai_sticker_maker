from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
from PIL import Image
import io
import torch
from diffusers import StableDiffusionPipeline
import numpy as np
from transformers import pipeline
import soundfile as sf  # only this is needed for audio

# -----------------------------
# App setup
# -----------------------------
app = FastAPI(title="⚡ Fast AI Sticker Generator")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------
# Paths & model config
# -----------------------------
OUTPUT_DIR = Path("generated_stickers")
OUTPUT_DIR.mkdir(exist_ok=True)

MODEL_BASE = "stabilityai/sd-turbo"
device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.float16 if device == "cuda" else torch.float32

print("🚀 Loading SD-Turbo model...")
pipe = StableDiffusionPipeline.from_pretrained(
    MODEL_BASE,
    torch_dtype=dtype,
    safety_checker=None,
)
pipe = pipe.to(device)
pipe.enable_attention_slicing()
if device == "cuda":
    pipe.enable_xformers_memory_efficient_attention()
print("✅ SD-Turbo model ready on", device)

# -----------------------------
# Whisper model (speech → text)
# -----------------------------
print("🎤 Loading Whisper model...")
speech2text = pipeline("automatic-speech-recognition", model="openai/whisper-small")
print("✅ Whisper model loaded!")

# -----------------------------
# Helper: Make background transparent
# -----------------------------
def make_transparent(img: Image.Image, bg_color=(255, 255, 255)) -> Image.Image:
    img = img.convert("RGBA")
    data = np.array(img)
    r, g, b, a = data.T
    mask = (r == bg_color[0]) & (g == bg_color[1]) & (b == bg_color[2])
    data[..., 3][mask] = 0
    return Image.fromarray(data)

# -----------------------------
# Routes
# -----------------------------
@app.get("/")
def home():
    return {"message": "Welcome to the ⚡ Fast AI Sticker Generator API!"}

# -----------------------------
# TEXT → STICKER
# -----------------------------
@app.post("/generate_sticker")
async def generate_sticker(text: str = Form(...)):
    try:
        prompt = f"{text}, cute cartoon sticker, bold outlines, colorful vector art, white background"
        with torch.autocast(device_type=device, dtype=dtype):
            result = pipe(prompt, height=384, width=384, num_inference_steps=12)
        image = result.images[0]
        image_transparent = make_transparent(image)

        file_path = OUTPUT_DIR / f"generated_sticker_{len(list(OUTPUT_DIR.glob('generated_sticker_*.png'))) + 1}.png"
        image_transparent.save(file_path)
        return FileResponse(file_path, media_type="image/png")
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

# -----------------------------
# IMAGE → STICKER
# -----------------------------
@app.post("/upload_image")
async def upload_image(image: UploadFile = File(...)):
    try:
        img = Image.open(io.BytesIO(await image.read())).convert("RGBA")
        img_transparent = make_transparent(img)
        img_resized = img_transparent.resize((384, 384))

        file_path = OUTPUT_DIR / f"uploaded_{image.filename}"
        img_resized.save(file_path)
        return FileResponse(file_path, media_type="image/png")
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})



# py -m uvicorn main:app --reload  