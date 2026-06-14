from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import base64

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class MeasureRequest(BaseModel):
    imageBase64: str
    hand: str
    finger: str
    coinReference: str
    currency: str

@app.post("/v1/nail-measurements/measure")
def measure(req: MeasureRequest):
    print("Hand:", req.hand)
    print("Finger:", req.finger)
    print("Coin:", req.coinReference)

    return {
        "widthMm": 14.8,
        "confidence": 0.95
    }