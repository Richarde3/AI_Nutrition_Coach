CREATE TABLE foods (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    calories DECIMAL(6,2) NOT NULL,
    protein DECIMAL(6,2) NOT NULL,
    fat DECIMAL(6,2) NOT NULL,
    carbohydrate DECIMAL(6,2) NOT NULL,
    display_unit VARCHAR(20),
    unit_weight DECIMAL(6,2)
);


CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE profiles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE,
    age INTEGER,
    gender VARCHAR(20),
    height_cm DECIMAL(5,2),
    weight_kg DECIMAL(5,2),
    activity_level VARCHAR(20),
    goal VARCHAR(30),

    CONSTRAINT fk_profiles_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);


CREATE TABLE meal_records (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    food_id INTEGER NOT NULL,
    meal_date DATE NOT NULL,
    meal_type VARCHAR(20) NOT NULL,
    amount_g DECIMAL(7,2) NOT NULL,

    CONSTRAINT fk_meal_records_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_meal_records_food
        FOREIGN KEY (food_id)
        REFERENCES foods(id)
        ON DELETE RESTRICT
);