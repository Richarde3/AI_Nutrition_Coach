from database import get_connection
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pwdlib import PasswordHash
from datetime import date, datetime, timedelta, timezone

import jwt
from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jwt.exceptions import InvalidTokenError



import os
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY = os.getenv("JWT_SECRET_KEY")

app = FastAPI()
password_hash = PasswordHash.recommended()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

def create_access_token(user_id: int):
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        "sub": str(user_id),
        "exp": expire,
    }

    return jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM,
    )

class LoginRequest(BaseModel):
    email: str
    password: str

def get_current_user_id(
  token: str = Depends(oauth2_scheme)
  ):
    credentials_exception = HTTPException(
        status_code=401,
        detail="認証情報を確認できません",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
        )

        user_id = payload.get("sub")

        if user_id is None:
            raise credentials_exception

        return int(user_id)

    except (InvalidTokenError, ValueError):
        raise credentials_exception

@app.post("/login")
def login(
    form_data: OAuth2PasswordRequestForm = Depends()
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    id,
                    email,
                    password_hash
                FROM users
                WHERE email = %s;
                """,
                (form_data.username,),
            )

            user = cur.fetchone()

    if user is None:
        raise HTTPException(
            status_code=401,
            detail="メールアドレスまたはパスワードが正しくありません"
        )

    user_id = user[0]
    stored_hash = user[2]

    if not password_hash.verify(
        form_data.password,
        stored_hash
    ):
        raise HTTPException(
            status_code=401,
            detail="メールアドレスまたはパスワードが正しくありません"
        )

    access_token = create_access_token(user_id)

    return {
        "access_token": access_token,
        "token_type": "bearer",
    }

@app.get("/users/me")
def get_current_user(
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    id,
                    email,
                    created_at
                FROM users
                WHERE id = %s;
                """,
                (current_user_id,),
            )

            user = cur.fetchone()

    if user is None:
        raise HTTPException(
            status_code=404,
            detail="ユーザーが見つかりません"
        )

    return {
        "id": user[0],
        "email": user[1],
        "created_at": user[2],
    }

class UserCreate(BaseModel):
  email: str
  password: str


class ProfileCreate(BaseModel):
    age: int | None = None
    gender: str | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    activity_level: str | None = None
    goal: str | None = None


class ProfileUpdate(BaseModel):
    age: int | None = None
    gender: str | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    activity_level: str | None = None
    goal: str | None = None

@app.post("/profiles", status_code=201)
def create_profile(
    profile: ProfileCreate,
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute(
                    """
                    INSERT INTO profiles (
                        current_user_id,
                        age,
                        gender,
                        height_cm,
                        weight_kg,
                        activity_level,
                        goal
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING
                        id,
                        user_id,
                        age,
                        gender,
                        height_cm,
                        weight_kg,
                        activity_level,
                        goal;
                    """,
                    (
                        profile.user_id,
                        profile.age,
                        profile.gender,
                        profile.height_cm,
                        profile.weight_kg,
                        profile.activity_level,
                        profile.goal,
                    ),
                )

                created = cur.fetchone()

            except Exception:
                raise HTTPException(
                    status_code=400,
                    detail="プロフィールを登録できませんでした"
                )

        conn.commit()

    return {
        "id": created[0],
        "user_id": created[1],
        "age": created[2],
        "gender": created[3],
        "height_cm": float(created[4]) if created[4] is not None else None,
        "weight_kg": float(created[5]) if created[5] is not None else None,
        "activity_level": created[6],
        "goal": created[7],
    }


@app.get("/profiles/me")
def get_profile(
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    id,
                    user_id,
                    age,
                    gender,
                    height_cm,
                    weight_kg,
                    activity_level,
                    goal
                FROM profiles
                WHERE user_id = %s;
                """,
                (current_user_id,),
            )

            profile = cur.fetchone()

    if profile is None:
        raise HTTPException(
            status_code=404,
            detail="プロフィールが見つかりません"
        )

    return {
        "id": profile[0],
        "user_id": profile[1],
        "age": profile[2],
        "gender": profile[3],
        "height_cm": float(profile[4]) if profile[4] is not None else None,
        "weight_kg": float(profile[5]) if profile[5] is not None else None,
        "activity_level": profile[6],
        "goal": profile[7],
    }


@app.patch("/profiles/me")
def update_profile(
    profile_update: ProfileUpdate,
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    age,
                    gender,
                    height_cm,
                    weight_kg,
                    activity_level,
                    goal
                FROM profiles
                WHERE user_id = %s;
                """,
                (current_user_id,),
            )

            current = cur.fetchone()

            if current is None:
                raise HTTPException(
                    status_code=404,
                    detail="プロフィールが見つかりません"
                )

            new_age = (
                profile_update.age
                if profile_update.age is not None
                else current[0]
            )
            new_gender = (
                profile_update.gender
                if profile_update.gender is not None
                else current[1]
            )
            new_height_cm = (
                profile_update.height_cm
                if profile_update.height_cm is not None
                else current[2]
            )
            new_weight_kg = (
                profile_update.weight_kg
                if profile_update.weight_kg is not None
                else current[3]
            )
            new_activity_level = (
                profile_update.activity_level
                if profile_update.activity_level is not None
                else current[4]
            )
            new_goal = (
                profile_update.goal
                if profile_update.goal is not None
                else current[5]
            )

            cur.execute(
                """
                UPDATE profiles
                SET
                    age = %s,
                    gender = %s,
                    height_cm = %s,
                    weight_kg = %s,
                    activity_level = %s,
                    goal = %s
                WHERE user_id = %s
                RETURNING
                    id,
                    user_id,
                    age,
                    gender,
                    height_cm,
                    weight_kg,
                    activity_level,
                    goal;
                """,
                (
                    new_age,
                    new_gender,
                    new_height_cm,
                    new_weight_kg,
                    new_activity_level,
                    new_goal,
                    current_user_id,
                ),
            )

            updated = cur.fetchone()

        conn.commit()

    return {
        "id": updated[0],
        "user_id": updated[1],
        "age": updated[2],
        "gender": updated[3],
        "height_cm": float(updated[4]) if updated[4] is not None else None,
        "weight_kg": float(updated[5]) if updated[5] is not None else None,
        "activity_level": updated[6],
        "goal": updated[7],
    }





foods = [
    {
        "id": 1,
        "name": "ご飯",
        "calories": 156.0,
        "protein": 2.5,
        "fat": 0.3,
        "carbohydrate": 37.1
    },
    {
        "id": 2,
        "name": "鶏むね肉",
        "calories": 108.0,
        "protein": 23.3,
        "fat": 1.5,
        "carbohydrate": 0.0
    },
    {
        "id": 3,
        "name": "納豆",
        "calories": 190.0,
        "protein": 16.5,
        "fat": 10.0,
        "carbohydrate": 12.1
    }
]


class FoodCreate(BaseModel):
    name: str
    calories: float
    protein: float
    fat: float
    carbohydrate: float
    display_unit: str | None = None
    unit_weight: float | None = None


@app.get("/")
def read_root():
    return {"message": "AI Nutrition Coach API"}


@app.get("/foods")
def get_foods():
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    id,
                    name,
                    calories,
                    protein,
                    fat,
                    carbohydrate,
                    display_unit,
                    unit_weight
                FROM foods
                ORDER BY id;
            """)

            rows = cur.fetchall()

    return [
        {
            "id": row[0],
            "name": row[1],
            "calories": float(row[2]),
            "protein": float(row[3]),
            "fat": float(row[4]),
            "carbohydrate": float(row[5]),
            "display_unit": row[6],
            "unit_weight": float(row[7]) if row[7] is not None else None,
        }
        for row in rows
    ]


@app.get("/foods/{food_id}")
def get_food(food_id: int):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    id,
                    name,
                    calories,
                    protein,
                    fat,
                    carbohydrate,
                    display_unit,
                    unit_weight
                FROM foods
                WHERE id = %s;
                """,
                (food_id,),
            )

            row = cur.fetchone()

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="指定された食品が見つかりません",
        )

    return {
        "id": row[0],
        "name": row[1],
        "calories": float(row[2]),
        "protein": float(row[3]),
        "fat": float(row[4]),
        "carbohydrate": float(row[5]),
        "display_unit": row[6],
        "unit_weight": float(row[7]) if row[7] is not None else None,
    }


@app.post("/foods", status_code=201)
def create_food(food: FoodCreate):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO foods (
                    name,
                    calories,
                    protein,
                    fat,
                    carbohydrate,
                    display_unit,
                    unit_weight
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                RETURNING
                    id,
                    name,
                    calories,
                    protein,
                    fat,
                    carbohydrate,
                    display_unit,
                    unit_weight;
                """,
                (
                    food.name,
                    food.calories,
                    food.protein,
                    food.fat,
                    food.carbohydrate,
                    food.display_unit,
                    food.unit_weight,
                ),
            )

            row = cur.fetchone()

        conn.commit()

    return {
        "id": row[0],
        "name": row[1],
        "calories": float(row[2]),
        "protein": float(row[3]),
        "fat": float(row[4]),
        "carbohydrate": float(row[5]),
        "display_unit": row[6],
        "unit_weight": float(row[7]) if row[7] is not None else None,
    }


class FoodUpdate(BaseModel):
    name: str | None = None
    calories: float | None = None
    protein: float | None = None
    fat: float | None = None
    carbohydrate: float | None = None


@app.patch("/foods/{food_id}")
def update_food(food_id: int, food_update: FoodUpdate):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    id,
                    name,
                    calories,
                    protein,
                    fat,
                    carbohydrate
                FROM foods
                WHERE id = %s;
                """,
                (food_id,),
            )

            current_food = cur.fetchone()

            if current_food is None:
                raise HTTPException(
                    status_code=404,
                    detail="指定された食品が見つかりません"
                )

            new_name = (
                food_update.name
                if food_update.name is not None
                else current_food[1]
            )

            new_calories = (
                food_update.calories
                if food_update.calories is not None
                else float(current_food[2])
            )

            new_protein = (
                food_update.protein
                if food_update.protein is not None
                else float(current_food[3])
            )

            new_fat = (
                food_update.fat
                if food_update.fat is not None
                else float(current_food[4])
            )

            new_carbohydrate = (
                food_update.carbohydrate
                if food_update.carbohydrate is not None
                else float(current_food[5])
            )

            cur.execute(
                """
                UPDATE foods
                SET
                    name = %s,
                    calories = %s,
                    protein = %s,
                    fat = %s,
                    carbohydrate = %s
                WHERE id = %s
                RETURNING
                    id,
                    name,
                    calories,
                    protein,
                    fat,
                    carbohydrate,
                    display_unit,
                    unit_weight;
                """,
                (
                    new_name,
                    new_calories,
                    new_protein,
                    new_fat,
                    new_carbohydrate,
                    food_id,
                ),
            )

            updated_food = cur.fetchone()

        conn.commit()

    return {
        "id": updated_food[0],
        "name": updated_food[1],
        "calories": float(updated_food[2]),
        "protein": float(updated_food[3]),
        "fat": float(updated_food[4]),
        "carbohydrate": float(updated_food[5]),
        "display_unit": updated_food[6],
        "unit_weight": (
            float(updated_food[7])
            if updated_food[7] is not None
            else None
        ),
    }

@app.delete("/foods/{food_id}")
def delete_food(food_id: int):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                DELETE FROM foods
                WHERE id = %s
                RETURNING id, name;
                """,
                (food_id,),
            )

            deleted_food = cur.fetchone()

        conn.commit()

    if deleted_food is None:
        raise HTTPException(
            status_code=404,
            detail="指定された食品が見つかりません"
        )

    return {
        "message": "食品を削除しました",
        "deleted_food": {
            "id": deleted_food[0],
            "name": deleted_food[1],
        },
    }


@app.get("/foods")
def get_foods():
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    id,
                    name,
                    calories,
                    protein,
                    fat,
                    carbohydrate,
                    display_unit,
                    unit_weight
                FROM foods
                ORDER BY id;
            """)

            rows = cur.fetchall()

    return [
        {
            "id": row[0],
            "name": row[1],
            "calories": float(row[2]),
            "protein": float(row[3]),
            "fat": float(row[4]),
            "carbohydrate": float(row[5]),
            "display_unit": row[6],
            "unit_weight": float(row[7]) if row[7] is not None else None,
        }
        for row in rows
    ]


class MealRecordCreate(BaseModel):
    food_id: int
    meal_date: date
    meal_type: str
    amount_g: float

@app.post("/meal-records", status_code=201)
def create_meal_record(
    meal: MealRecordCreate,
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO meal_records (
                    user_id,
                    food_id,
                    meal_date,
                    meal_type,
                    amount_g
                )
                VALUES (%s, %s, %s, %s, %s)
                RETURNING
                    id,
                    user_id,
                    food_id,
                    meal_date,
                    meal_type,
                    amount_g;
                """,
                (
                    current_user_id,
                    meal.food_id,
                    meal.meal_date,
                    meal.meal_type,
                    meal.amount_g,
                ),
            )

            row = cur.fetchone()

        conn.commit()

    return {
        "id": row[0],
        "user_id": row[1],
        "food_id": row[2],
        "meal_date": row[3],
        "meal_type": row[4],
        "amount_g": float(row[5]),
    }

@app.get("/meal-records")
def get_meal_records(
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    m.id,
                    m.user_id,
                    m.food_id,
                    f.name,
                    m.meal_date,
                    m.meal_type,
                    m.amount_g,
                    f.calories,
                    f.protein,
                    f.fat,
                    f.carbohydrate
                FROM meal_records m
                JOIN foods f
                    ON m.food_id = f.id
                WHERE m.user_id = %s
                ORDER BY m.meal_date DESC, m.id DESC;
                """,
                (current_user_id,),
            )

            rows = cur.fetchall()

    return [
        {
            "id": row[0],
            "user_id": row[1],
            "food_id": row[2],
            "food_name": row[3],
            "meal_date": row[4],
            "meal_type": row[5],
            "amount_g": float(row[6]),
            "calories": float(row[7]) * float(row[6]) / 100,
            "protein": float(row[8]) * float(row[6]) / 100,
            "fat": float(row[9]) * float(row[6]) / 100,
            "carbohydrate": float(row[10]) * float(row[6]) / 100,
        }
        for row in rows
    ]

@app.get("/daily-summary")
def get_daily_summary(
    target_date: date,
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    COALESCE(SUM(f.calories * m.amount_g / 100), 0),
                    COALESCE(SUM(f.protein * m.amount_g / 100), 0),
                    COALESCE(SUM(f.fat * m.amount_g / 100), 0),
                    COALESCE(SUM(f.carbohydrate * m.amount_g / 100), 0)
                FROM meal_records m
                JOIN foods f
                    ON m.food_id = f.id
                WHERE
                    m.user_id = %s
                    AND m.meal_date = %s;
                """,
                (current_user_id, target_date),
            )

            row = cur.fetchone()

    return {
        "user_id": current_user_id,
        "date": target_date,
        "total_calories": round(float(row[0]), 2),
        "total_protein": round(float(row[1]), 2),
        "total_fat": round(float(row[2]), 2),
        "total_carbohydrate": round(float(row[3]), 2),
    }


class MealRecordUpdate(BaseModel):
  food_id: int | None = None
  meal_date: date | None = None
  meal_type: str | None = None
  amount_g: float | None = None


@app.get("/meal-records/{meal_record_id}")
def get_meal_record(
    meal_record_id: int,
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    m.id,
                    m.user_id,
                    m.food_id,
                    f.name,
                    m.meal_date,
                    m.meal_type,
                    m.amount_g,
                    f.calories,
                    f.protein,
                    f.fat,
                    f.carbohydrate
                FROM meal_records m
                JOIN foods f
                    ON m.food_id = f.id
                WHERE m.id = %s 
                AND m.user_id = %s;
                """,
                (meal_record_id, current_user_id),
            )

            row = cur.fetchone()

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="指定された食事記録が見つかりません"
        )

    amount_g = float(row[6])

    return {
        "id": row[0],
        "user_id": row[1],
        "food_id": row[2],
        "food_name": row[3],
        "meal_date": row[4],
        "meal_type": row[5],
        "amount_g": amount_g,
        "calories": round(float(row[7]) * amount_g / 100, 2),
        "protein": round(float(row[8]) * amount_g / 100, 2),
        "fat": round(float(row[9]) * amount_g / 100, 2),
        "carbohydrate": round(float(row[10]) * amount_g / 100, 2),
    }


@app.patch("/meal-records/{meal_record_id}")
def update_meal_record(
    meal_record_id: int,
    meal_update: MealRecordUpdate,
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:

            cur.execute(
    """
    SELECT
        food_id,
        meal_date,
        meal_type,
        amount_g
    FROM meal_records
    WHERE id = %s
      AND user_id = %s;
    """,
    (meal_record_id, current_user_id),
)
            

            current = cur.fetchone()

            if current is None:
                raise HTTPException(
                    status_code=404,
                    detail="指定された食事記録が見つかりません"
                )

            new_food_id = (
                meal_update.food_id
                if meal_update.food_id is not None
                else current[0]
            )

            new_meal_date = (
                meal_update.meal_date
                if meal_update.meal_date is not None
                else current[1]
            )

            new_meal_type = (
                meal_update.meal_type
                if meal_update.meal_type is not None
                else current[2]
            )

            new_amount_g = (
                meal_update.amount_g
                if meal_update.amount_g is not None
                else float(current[3])
            )

            cur.execute(
    """
    UPDATE meal_records
    SET
        food_id = %s,
        meal_date = %s,
        meal_type = %s,
        amount_g = %s
    WHERE id = %s
      AND user_id = %s
    RETURNING
        id,
        user_id,
        food_id,
        meal_date,
        meal_type,
        amount_g;
    """,
    (
        new_food_id,
        new_meal_date,
        new_meal_type,
        new_amount_g,
        meal_record_id,
        current_user_id,
    ),
)

            updated = cur.fetchone()

        conn.commit()

    return {
        "id": updated[0],
        "user_id": updated[1],
        "food_id": updated[2],
        "meal_date": updated[3],
        "meal_type": updated[4],
        "amount_g": float(updated[5]),
    }

@app.delete("/meal-records/{meal_record_id}")
def delete_meal_record(
    meal_record_id: int,
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
    """
    DELETE FROM meal_records
    WHERE id = %s
      AND user_id = %s
    RETURNING
        id,
        user_id,
        food_id,
        meal_date,
        meal_type,
        amount_g;
    """,
    (meal_record_id, current_user_id),
)

            deleted = cur.fetchone()

        conn.commit()

    if deleted is None:
        raise HTTPException(
            status_code=404,
            detail="指定された食事記録が見つかりません"
        )

    return {
        "message": "食事記録を削除しました",
        "deleted_record": {
            "id": deleted[0],
            "user_id": deleted[1],
            "food_id": deleted[2],
            "meal_date": deleted[3],
            "meal_type": deleted[4],
            "amount_g": float(deleted[5]),
        },
    }


def calculate_nutrition_targets(profile):
    age = profile["age"]
    gender = profile["gender"]
    height_cm = profile["height_cm"]
    weight_kg = profile["weight_kg"]
    activity_level = profile["activity_level"]
    goal = profile["goal"]

    if gender == "male":
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
    else:
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161

    activity_factors = {
        "low": 1.2,
        "light": 1.375,
        "moderate": 1.55,
        "high": 1.725,
        "very_high": 1.9,
    }

    activity_factor = activity_factors.get(
        activity_level,
        1.55
    )

    tdee = bmr * activity_factor

    if goal == "lose":
        target_calories = tdee - 300
    elif goal == "gain":
        target_calories = tdee + 300
    else:
        target_calories = tdee

    protein = weight_kg * 1.6
    fat = target_calories * 0.25 / 9
    carbohydrate = (
        target_calories
        - protein * 4
        - fat * 9
    ) / 4

    return {
        "bmr": round(bmr, 2),
        "tdee": round(tdee, 2),
        "target_calories": round(target_calories, 2),
        "target_protein": round(protein, 2),
        "target_fat": round(fat, 2),
        "target_carbohydrate": round(carbohydrate, 2),
    }

@app.get("/nutrition-targets")
def get_nutrition_targets(
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    age,
                    gender,
                    height_cm,
                    weight_kg,
                    activity_level,
                    goal
                FROM profiles
                WHERE user_id = %s;
                """,
                (current_user_id,),
            )

            row = cur.fetchone()

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="プロフィールが見つかりません"
        )

    profile = {
        "age": row[0],
        "gender": row[1],
        "height_cm": float(row[2]),
        "weight_kg": float(row[3]),
        "activity_level": row[4],
        "goal": row[5],
    }

    return calculate_nutrition_targets(profile)    

@app.get("/nutrition-status")
def get_nutrition_status(
    target_date: date,
    current_user_id: int = Depends(get_current_user_id)
):
    with get_connection() as conn:
        with conn.cursor() as cur:
            # 1. プロフィール取得
            cur.execute(
                """
                SELECT
                    age,
                    gender,
                    height_cm,
                    weight_kg,
                    activity_level,
                    goal
                FROM profiles
                WHERE user_id = %s;
                """,
                (current_user_id,),
            )

            profile_row = cur.fetchone()

            if profile_row is None:
                raise HTTPException(
                    status_code=404,
                    detail="プロフィールが見つかりません"
                )

            # 2. 指定日の摂取量を集計
            cur.execute(
                """
                SELECT
                    COALESCE(SUM(f.calories * m.amount_g / 100), 0),
                    COALESCE(SUM(f.protein * m.amount_g / 100), 0),
                    COALESCE(SUM(f.fat * m.amount_g / 100), 0),
                    COALESCE(SUM(f.carbohydrate * m.amount_g / 100), 0)
                FROM meal_records m
                JOIN foods f
                    ON m.food_id = f.id
                WHERE
                    m.user_id = %s
                    AND m.meal_date = %s;
                """,
                (current_user_id, target_date),
            )

            actual_row = cur.fetchone()

    profile = {
        "age": profile_row[0],
        "gender": profile_row[1],
        "height_cm": float(profile_row[2]),
        "weight_kg": float(profile_row[3]),
        "activity_level": profile_row[4],
        "goal": profile_row[5],
    }

    targets = calculate_nutrition_targets(profile)

    actual_calories = round(float(actual_row[0]), 2)
    actual_protein = round(float(actual_row[1]), 2)
    actual_fat = round(float(actual_row[2]), 2)
    actual_carbohydrate = round(float(actual_row[3]), 2)

    remaining_calories = round(
        targets["target_calories"] - actual_calories,
        2
    )
    remaining_protein = round(
        targets["target_protein"] - actual_protein,
        2
    )
    remaining_fat = round(
        targets["target_fat"] - actual_fat,
        2
    )
    remaining_carbohydrate = round(
        targets["target_carbohydrate"] - actual_carbohydrate,
        2
    )

    return {
        "date": target_date,
        "target": {
            "calories": targets["target_calories"],
            "protein": targets["target_protein"],
            "fat": targets["target_fat"],
            "carbohydrate": targets["target_carbohydrate"],
        },
        "actual": {
            "calories": actual_calories,
            "protein": actual_protein,
            "fat": actual_fat,
            "carbohydrate": actual_carbohydrate,
        },
        "remaining": {
            "calories": remaining_calories,
            "protein": remaining_protein,
            "fat": remaining_fat,
            "carbohydrate": remaining_carbohydrate,
        },
    }