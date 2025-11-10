from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
from PIL import Image
import io
import torch
from diffusers import StableDiffusionPipeline
import numpy as np
from transformers import pipeline
from tempfile import NamedTemporaryFile

# -------------------------------------------------
# App setup
# -------------------------------------------------
app = FastAPI(title="⚡ Fast AI Sticker Generator")

# Allow frontend access (Flutter web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # You can later restrict this to your domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -------------------------------------------------
# Paths & model config
# -------------------------------------------------
OUTPUT_DIR = Path("generated_stickers")
OUTPUT_DIR.mkdir(exist_ok=True)

MODEL_BASE = "stabilityai/sd-turbo"  # ⚡ FAST model
device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.float16 if device == "cuda" else torch.float32

print("🚀 Loading SD-Turbo model... (this is fast)")
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

# -------------------------------------------------
# Whisper model (for voice → text)
# -------------------------------------------------
print("🎤 Loading Whisper model...")
speech2text = pipeline("automatic-speech-recognition", model="openai/whisper-small")
print("✅ Whisper model loaded!")

# -------------------------------------------------
# Helper: Make background transparent
# -------------------------------------------------
def make_transparent(img: Image.Image, bg_color=(255, 255, 255)) -> Image.Image:
    img = img.convert("RGBA")
    data = np.array(img)
    r, g, b, a = data.T
    mask = (r == bg_color[0]) & (g == bg_color[1]) & (b == bg_color[2])
    data[..., 3][mask] = 0
    return Image.fromarray(data)

# -------------------------------------------------
# Routes
# -------------------------------------------------
@app.get("/")
def home():
    return {"message": "Welcome to the ⚡ Fast AI Sticker Generator API!"}

# ------------------------------
# TEXT → STICKER
# ------------------------------
@app.post("/generate_sticker")
async def generate_sticker(text: str = Form(...)):
    prompt = f"{text}, cute cartoon sticker, bold outlines, colorful vector art, white background"

    # Use autocast for speed + efficiency
    with torch.autocast(device_type=device, dtype=torch.float16 if device == "cuda" else torch.float32):
        result = pipe(prompt, height=384, width=384, num_inference_steps=12)

    image = result.images[0]
    image_transparent = make_transparent(image)

    file_path = OUTPUT_DIR / f"generated_sticker_{len(list(OUTPUT_DIR.glob('generated_sticker_*.png'))) + 1}.png"
    image_transparent.save(file_path)

    return FileResponse(file_path, media_type="image/png")

# ------------------------------
# IMAGE → STICKER
# ------------------------------
@app.post("/upload_image")
async def upload_image(image: UploadFile = File(...)):
    img = Image.open(io.BytesIO(await image.read())).convert("RGBA")
    img_transparent = make_transparent(img)
    img_resized = img_transparent.resize((384, 384))

    file_path = OUTPUT_DIR / f"uploaded_{image.filename}"
    img_resized.save(file_path)

    return FileResponse(file_path, media_type="image/png")

# ------------------------------
# VOICE → STICKER
# ------------------------------
@app.post("/generate_sticker_from_voice")
async def generate_sticker_from_voice(voice: UploadFile = File(...)):
    # Read the uploaded voice file into memory
    voice_bytes = await voice.read()
    voice_buffer = io.BytesIO(voice_bytes)

    # Transcribe using Whisper directly from bytes
    result = speech2text(voice_buffer)
    transcribed_text = result["text"]

    # Create sticker prompt
    prompt = f"{transcribed_text}, cartoon style sticker, bold outlines, colorful vector, white background"
    
    # Generate sticker
    with torch.autocast(device_type=device, dtype=torch.float16 if device == "cuda" else torch.float32):
        result = pipe(prompt, height=384, width=384, num_inference_steps=12)

    image = result.images[0]
    image_transparent = make_transparent(image)

    # Save sticker
    file_path = OUTPUT_DIR / f"voice_generated_sticker_{len(list(OUTPUT_DIR.glob('voice_generated_sticker_*.png'))) + 1}.png"
    image_transparent.save(file_path)

    return FileResponse(file_path, media_type="image/png")

# py -m uvicorn main:app --reload  