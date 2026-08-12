from database import get_connection
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import date

app = FastAPI()

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
    user_id: int
    food_id: int
    meal_date: date
    meal_type: str
    amount_g: float

@app.post("/meal-records", status_code=201)
def create_meal_record(meal: MealRecordCreate):
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
                    meal.user_id,
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
def get_meal_records():
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
                ORDER BY m.meal_date DESC, m.id DESC;
                """
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
def get_daily_summary(user_id: int, target_date: date):
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
                (user_id, target_date),
            )

            row = cur.fetchone()

    return {
        "user_id": user_id,
        "date": target_date,
        "total_calories": round(float(row[0]), 2),
        "total_protein": round(float(row[1]), 2),
        "total_fat": round(float(row[2]), 2),
        "total_carbohydrate": round(float(row[3]), 2),
    }