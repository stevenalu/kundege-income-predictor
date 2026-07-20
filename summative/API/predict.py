import io
from enum import Enum

import pandas as pd
import uvicorn
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from income_model import predict_income, retrain_model


# closed value lists -> Swagger shows these as dropdowns and rejects anything else
class Education(str, Enum):
    primary = "Primary or Less"
    secondary = "Secondary"
    tvet = "TVET"
    university = "University"


class Gender(str, Enum):
    male = "Male"
    female = "Female"


class Location(str, Enum):
    urban = "Urban"
    rural = "Rural"


class Formality(str, Enum):
    formal = "Formal"
    informal = "Informal"


class Region(str, Enum):
    kigali = "Kigali"
    eastern = "Eastern"
    western = "Western"
    northern = "Northern"
    southern = "Southern"


class Sector(str, Enum):
    agriculture = "Agriculture"
    construction = "Construction"
    education = "Education"
    healthcare = "Healthcare"
    ict = "ICT"
    retail = "Retail"


class DigitalSkill(str, Enum):
    basic = "Basic"
    intermediate = "Intermediate"
    advanced = "Advanced"


class Profile(BaseModel):
    age: int = Field(..., ge=16, le=25, description="Age of the youth (16-25)")
    education_level: Education
    gender: Gender
    location_type: Location
    formal_informal: Formality
    region: Region
    sector: Sector
    digital_skills: DigitalSkill = DigitalSkill.basic
    skill_count: int = Field(0, ge=0, le=10, description="Number of practical skills")


app = FastAPI(
    title="Ku ndege Income Estimator API",
    description="Estimates the monthly income (RWF) of a young Rwandan worker from "
                "their profile, and retrains the saved model when new data is uploaded.",
    version="1.0.0",
)

# CORS: only my own Flutter web build and local dev machines may call this API.
# We pin the origins instead of using "*", limit methods to the two we use, and
# allow only the JSON content-type header. Credentials are on for future auth.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://kundege-income.onrender.com"],
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


@app.get("/")
def home():
    return {"message": "Income estimator is running. Open /docs for Swagger, "
                       "POST /predict to estimate, POST /retrain to update the model."}


@app.post("/predict")
def predict(profile: Profile):
    try:
        amount = predict_income(
            profile.age, profile.education_level.value, profile.gender.value,
            profile.location_type.value, profile.formal_informal.value,
            profile.region.value, profile.sector.value,
            profile.digital_skills.value, profile.skill_count,
        )
        return {"estimated_monthly_income_rwf": amount}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/retrain")
async def retrain(file: UploadFile = File(...)):
    try:
        content = await file.read()
        df = pd.read_csv(io.BytesIO(content))
        return retrain_model(df)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
