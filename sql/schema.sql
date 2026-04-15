DROP TABLE IF EXISTS healthcare_data;

CREATE TABLE healthcare_data (
    "Name" VARCHAR(255) NOT NULL,
    "Age" INTEGER NOT NULL,
    "Gender" VARCHAR(50) NOT NULL,
    "Blood Type" VARCHAR(10) NOT NULL,
    "Medical Condition" TEXT NOT NULL,
    "Date of Admission" DATE NOT NULL,
    "Doctor" VARCHAR(255) NOT NULL,
    "Hospital" VARCHAR(255) NOT NULL,
    "Insurance Provider" VARCHAR(255),
    "Billing Amount" DECIMAL(10, 2),
    "Admission Type" VARCHAR(50) NOT NULL,
    "Discharge Date" DATE,
    "Medication" TEXT,
    "Test Results" TEXT
);