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

INSERT INTO foods
    (name, calories, protein, fat, carbohydrate, display_unit, unit_weight)
VALUES
    ('ご飯', 156.0, 2.5, 0.3, 37.1, 'g', 1.0),
    ('鶏むね肉', 108.0, 23.3, 1.5, 0.0, 'g', 1.0),
    ('納豆', 190.0, 16.5, 10.0, 12.1, 'パック', 40.0);


SELECT *
FROM foods;