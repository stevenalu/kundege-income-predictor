import ast
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import mean_squared_error, r2_score

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "best_model.pkl"

# load the saved bundle once at startup (model + scaler + column order)
bundle = joblib.load(MODEL_PATH)
model = bundle["model"]
scaler = bundle["scaler"]
FEATURES = bundle["columns"]

EDU = {"Primary or Less": 1, "Secondary": 2, "TVET": 2.5, "University": 3}
DIGITAL = {"Basic": 1, "Intermediate": 2, "Advanced": 3}
HOUSEHOLD = {"Low": 1, "Medium": 2, "High": 3}
EFFECT = {"Ineffective": 1, "Moderately Effective": 2, "Effective": 3}


def _count_skills(v):
    try:
        items = ast.literal_eval(v)
        return len([x for x in items if isinstance(x, str) and len(x) > 1])
    except Exception:
        return 0


def predict_income(age, education_level, gender, location_type, formal_informal,
                   region, sector, digital_skills, skill_count):
    """Estimate a worker's monthly income (RWF) from their profile."""
    row = {c: 0 for c in FEATURES}
    row["age"] = age
    row["age_sq"] = age ** 2
    row["gender"] = 1 if gender == "Male" else 0
    row["location_type"] = 1 if location_type == "Urban" else 0
    row["formal_informal"] = 1 if formal_informal == "Formal" else 0
    row["education_level"] = EDU[education_level]
    row["digital_skills_level"] = DIGITAL[digital_skills]
    row["skill_count"] = skill_count
    row["edu_x_age"] = row["education_level"] * age
    row["urban_formal"] = row["location_type"] * row["formal_informal"]

    for col in (f"region_{region}", f"sector_of_interest_{sector}",
                f"current_employment_sector_{sector}"):
        if col in row:
            row[col] = 1

    x = pd.DataFrame([row])[FEATURES]
    x = scaler.transform(x)
    return round(float(model.predict(x)[0]), 2)


def _prepare(df):
    # same steps used when the model was first trained
    df = df[df["monthly_income"].notna()].copy()
    df["program_type"] = df["program_type"].fillna("None")

    for c in ["education_mismatch", "training_participation"]:
        df[c] = df[c].astype(int)
    df["gender"] = (df["gender"] == "Male").astype(int)
    df["location_type"] = (df["location_type"] == "Urban").astype(int)
    df["formal_informal"] = (df["formal_informal"] == "Formal").astype(int)
    df["education_level"] = df["education_level"].map(EDU)
    df["digital_skills_level"] = df["digital_skills_level"].map(DIGITAL)
    df["household_income"] = df["household_income"].map(HOUSEHOLD)
    df["intervention_effectiveness"] = df["intervention_effectiveness"].map(EFFECT)
    df["skill_count"] = df["technical_skills"].apply(_count_skills)

    df = pd.get_dummies(df, columns=["sector_of_interest", "current_employment_sector",
                                     "region", "program_type"], drop_first=True)
    df["edu_x_age"] = df["education_level"] * df["age"]
    df["age_sq"] = df["age"] ** 2
    df["urban_formal"] = df["location_type"] * df["formal_informal"]

    y = df["monthly_income"].astype(float)
    X = df.reindex(columns=FEATURES, fill_value=0).fillna(0).astype(float)
    return X, y


def retrain_model(df):
    """Retrain the already-saved model on a freshly uploaded dataset."""
    global model
    X, y = _prepare(df)
    X_scaled = scaler.transform(X)          # reuse the scaler the model was trained with

    model.fit(X_scaled, y)                   # retrain the SAME loaded model on the new data

    # overwrite the saved bundle so the updated model is what gets served next
    joblib.dump({"model": model, "scaler": scaler,
                 "columns": FEATURES, "uses_scaler": True}, MODEL_PATH)

    preds = model.predict(X_scaled)
    return {
        "message": "Existing model retrained on the uploaded data",
        "rows_used": int(len(y)),
        "features_used": int(X.shape[1]),
        "train_rmse": round(float(np.sqrt(mean_squared_error(y, preds))), 2),
        "train_r2": round(float(r2_score(y, preds)), 4),
    }
