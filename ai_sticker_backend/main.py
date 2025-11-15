from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import FileResponse
from pathlib import Path
from PIL import Image
import io
import torch
from diffusers import StableDiffusionPipeline, DPMSolverMultistepScheduler
import numpy as np
from transformers import pipeline
from tempfile import NamedTemporaryFile
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="AI Sticker Generator")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

OUTPUT_DIR = Path("generated_stickers")
OUTPUT_DIR.mkdir(exist_ok=True)


MODEL_BASE = "runwayml/stable-diffusion-v1-5"
LORA_ADAPTER = Path(r"E:\whatsapp\ai_sticker_backend\StickersRedmond15Version-Stickers-Sticker.safetensors")

print("🚀 Loading Stable Diffusion pipeline... this may take a while.")

pipe = StableDiffusionPipeline.from_pretrained(
    MODEL_BASE,
    torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32
)


pipe.load_lora_weights(str(LORA_ADAPTER.parent), weight_name=LORA_ADAPTER.name)
pipe.fuse_lora()


pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)
pipe = pipe.to("cuda" if torch.cuda.is_available() else "cpu")

print("✅ Model and LoRA loaded successfully!")

#
print("🎤 Loading Hugging Face Whisper model for speech-to-text...")
speech2text = pipeline("automatic-speech-recognition", model="openai/whisper-small")
print("✅ Whisper model loaded!")

def make_transparent(img: Image.Image, bg_color=(255, 255, 255)) -> Image.Image:
    """Convert background (white or specified color) to transparent."""
    img = img.convert("RGBA")
    data = np.array(img)
    r, g, b, a = data.T
    mask = (r == bg_color[0]) & (g == bg_color[1]) & (b == bg_color[2])
    data[..., 3][mask] = 0
    return Image.fromarray(data)


@app.get("/")
def home():
    return {"message": "Welcome to the AI Sticker Generator API!"}

#
@app.post("/generate_sticker")
async def generate_sticker(text: str = Form(...)):
    """
    Takes text input and generates a sticker (512x512 PNG)
    """
    prompt = f"{text}, cartoon style, bright colors, sticker, bold outlines, vector style, white background"
    
    
    result = pipe(prompt, height=512, width=512)
    image = result.images[0]

    
    image_transparent = make_transparent(image)

    
    existing = list(OUTPUT_DIR.glob("generated_sticker_*.png"))
    file_path = OUTPUT_DIR / f"generated_sticker_{len(existing) + 1}.png"
    image_transparent.save(file_path)

    return FileResponse(file_path, media_type="image/png")


@app.post("/upload_image")
async def upload_image(image: UploadFile = File(...)):
    """
    Accepts an uploaded image, removes background, resizes to 512x512
    """
    img = Image.open(io.BytesIO(await image.read())).convert("RGBA")
    img_transparent = make_transparent(img)
    img_resized = img_transparent.resize((512, 512))

    file_path = OUTPUT_DIR / f"uploaded_{image.filename}"
    img_resized.save(file_path)

    return FileResponse(file_path, media_type="image/png")


@app.post("/generate_sticker_from_voice")
async def generate_sticker_from_voice(voice: UploadFile = File(...)):
    """
    Takes a voice file, converts speech to text, then generates a sticker
    """
    
    with NamedTemporaryFile(delete=False, suffix=voice.filename) as tmp:
        tmp.write(await voice.read())
        tmp_path = tmp.name

    
    result = speech2text(tmp_path)
    transcribed_text = result["text"]

    
    prompt = f"{transcribed_text}, cartoon style, bright colors, sticker, bold outlines, vector style, white background"
    image = pipe(prompt, height=512, width=512).images[0]

    
    image_transparent = make_transparent(image)

    
    existing = list(OUTPUT_DIR.glob("voice_generated_sticker_*.png"))
    file_path = OUTPUT_DIR / f"voice_generated_sticker_{len(existing) + 1}.png"
    image_transparent.save(file_path)

    return FileResponse(file_path, media_type="image/png")




# py -m uvicorn main:app --reload  