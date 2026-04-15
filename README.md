# 🏥 Healthcare Analytics Project

An end-to-end data analytics pipeline built on a real-world healthcare dataset. This project covers data cleaning, database ingestion, and advanced SQL-based analysis to surface actionable insights around billing patterns, patient risk, hospital efficiency, and provider performance.

> **Dataset Source:** [Healthcare Dataset — Kaggle (prasad22)](https://www.kaggle.com/datasets/prasad22/healthcare-dataset?resource=download)

---

## 📁 Project Structure

```
Healthcare Analytics Project/
│
├── data/
│   ├── raw/                        # Original, unmodified CSV from Kaggle
│   │   └── healthcare_dataset.csv
│   └── clean/                      # Cleaned and transformed output
│       └── cleaned_healthcare_data.csv
│
├── sql/
│   ├── schema.sql                  # Table definition (CREATE TABLE)
│   └── sql_queries.sql             # All analytical queries / insights
│
├── src/
│   ├── data_cleaning.py            # Cleans and exports the raw dataset
│   ├── load_data_to_db.py          # Loads cleaned CSV into PostgreSQL
│   └── utils.py                    # Shared DB connection helper
│
├── .env                            # Local environment variables (not committed)
└── README.md
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Language** | Python 3 |
| **Database** | PostgreSQL |
| **ORM / DB Driver** | SQLAlchemy + psycopg2 |
| **Data Manipulation** | pandas |
| **Environment Config** | python-dotenv |
| **Query Language** | SQL (PostgreSQL dialect) |

---

## ⚙️ Pipeline Walkthrough

### 1. Raw Data
The raw dataset (`healthcare_dataset.csv`) was downloaded from Kaggle. It contains **1,000 synthetic patient records** with the following fields:

| Column | Description |
|---|---|
| `Name` | Patient full name |
| `Age` | Patient age (integer) |
| `Gender` | Male / Female |
| `Blood Type` | ABO blood group |
| `Medical Condition` | Primary diagnosis (e.g. Cancer, Diabetes) |
| `Date of Admission` | Hospital admission date |
| `Doctor` | Treating physician |
| `Hospital` | Facility name |
| `Insurance Provider` | Payer (e.g. Aetna, Cigna, Medicare) |
| `Billing Amount` | Total bill in USD |
| `Room Number` | Ward/room number *(removed during cleaning)* |
| `Admission Type` | Emergency / Urgent / Elective |
| `Discharge Date` | Date patient was discharged |
| `Medication` | Primary medication prescribed |
| `Test Results` | Normal / Abnormal / Inconclusive |

---

### 2. Data Cleaning — `data_cleaning.py`

The cleaning script performs the following transformations before anything hits the database:

- **Drops `Room Number`** — this column carries no analytical value and caused schema conflicts
- **Removes duplicate rows** via `drop_duplicates()`
- **Casts all columns to correct types** — dates to `datetime`, numerics to `int`/`float`, text fields to `str`
- Writes the cleaned output to `data/clean/cleaned_healthcare_data.csv`

```bash
# Run from the /src directory
python data_cleaning.py
```

---

### 3. Schema Definition — `schema.sql`

Before loading data, the target table is created in PostgreSQL:

```sql
CREATE TABLE healthcare_data (
    "Name"              VARCHAR(255) NOT NULL,
    "Age"               INTEGER NOT NULL,
    "Gender"            VARCHAR(50) NOT NULL,
    "Blood Type"        VARCHAR(10) NOT NULL,
    "Medical Condition" TEXT NOT NULL,
    "Date of Admission" DATE NOT NULL,
    "Doctor"            VARCHAR(255) NOT NULL,
    "Hospital"          VARCHAR(255) NOT NULL,
    "Insurance Provider" VARCHAR(255),
    "Billing Amount"    DECIMAL(10, 2),
    "Admission Type"    VARCHAR(50) NOT NULL,
    "Discharge Date"    DATE,
    "Medication"        TEXT,
    "Test Results"      TEXT
);
```

---

### 4. Loading Data — `load_data_to_db.py`

Uses **SQLAlchemy + pandas** to load the cleaned CSV directly into the `healthcare_data` PostgreSQL table:

```python
df.to_sql("healthcare_data", engine, if_exists="append", index=False)
```

Database credentials are read securely from a `.env` file via `python-dotenv`.

```bash
# Run from the /src directory
python load_data_to_db.py
```

---

### 5. Database Connection — `utils.py`

A shared `get_db_engine()` helper reads `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, and `DB_NAME` from `.env` and returns a SQLAlchemy engine using the `postgresql+psycopg2` dialect. Validates that no credentials are missing before attempting a connection.

---

### 6. `.env` Configuration

Create a `.env` file in the project root with the following keys (never commit this file):

```
DB_USER=your_username
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432
DB_NAME=your_database_name
```

---

## 📊 SQL Insights — `sql_queries.sql`

### 1 — Billing Anomaly Detection
Flags patients whose billing amount is **more than 2 standard deviations above the average** for their specific condition and admission type. Uses Z-score calculation to surface potential overbilling or unusually complex cases.

**Key techniques:** `STDDEV()`, Z-score via arithmetic, `NULLIF`, `JOIN` on CTE stats.

---

### 2 — Patient Risk Segmentation
Assigns each patient a **composite risk score** across four dimensions:
- **Age** (elderly patients = higher baseline risk)
- **Length of stay** (longer LOS = more severe presentation)
- **Test results** (Abnormal = high concern)
- **Admission type** (Emergency = most acute)

Patients are then labelled: `CRITICAL`, `HIGH RISK`, `MODERATE`, or `LOW RISK`.

**Key techniques:** Multi-factor `CASE WHEN` scoring, CTE chaining, computed `total_risk_score`.

---

### 3 — Doctor Performance Scorecard
Ranks all doctors by **patient volume, total revenue generated, average length of stay, and test outcome rates** (normal vs abnormal). Dual `RANK()` windows allow comparison of volume rank versus billing rank.

**Key techniques:** `FILTER`, `RANK() OVER()`, `COUNT()`, grouped aggregations.

---

### 4 — Insurance Provider Profitability & Coverage Analysis
Breaks down each insurer's patient population by medical condition — showing **min/max/avg billing**, total billed per condition, and split by admission type (Emergency, Elective, Urgent).

**Key techniques:** Multi-column `GROUP BY`, `FILTER` aggregations, `SUM / AVG / MIN / MAX`.

---

### 5 — Month-over-Month Admission Trends & Seasonality
Tracks **monthly admission volumes and total billing** across the full date range. Uses `LAG()` to compute month-over-month growth percentages — useful for identifying seasonal demand spikes (e.g. winter respiratory illness peaks).

**Key techniques:** `EXTRACT()`, `TO_CHAR()`, `LAG() OVER()`, MoM % growth formula.

---

### 6 — Repeat Patient / Comorbidity Proxy
Identifies patients who were **admitted more than once**, aggregates all their conditions and medications into a single row using `STRING_AGG`, and calculates lifetime billing vs average billing per visit.

**Key techniques:** `STRING_AGG`, `HAVING COUNT(*) > 1`, date range as patient duration, lifetime billing.

---

### 7 — Hospital Efficiency Benchmarking
Compares every hospital on **average length of stay, billing per day, abnormal outcome rate, and doctor headcount**. Uses `NTILE(4)` to assign each hospital a quartile rank for both LOS efficiency and outcome quality.

**Key techniques:** `NTILE(4) OVER()`, billing-per-day derived metric, `COUNT(DISTINCT)`.

---

### 8 — Medication Effectiveness Proxy
For every medication × condition combination, calculates the **normal outcome rate (%)**, average billing, and average length of stay — giving a surface-level signal of treatment pattern effectiveness.

**Key techniques:** `FILTER` aggregation, normal rate percentage, grouped by medication + condition.

---

### 9 — Age-Gender Health Matrix
Cross-tabulates **age band × gender × medical condition** to reveal demographic health patterns. Uses a proportional window function to show what share of each demographic's total admissions each condition makes up.

**Key techniques:** Age banding with `CASE WHEN`, `SUM() OVER (PARTITION BY ...)` for within-group proportions.

---

### 10 — Blood Type & Condition Risk Correlation
Examines whether certain **blood types are disproportionately associated** with specific conditions or worse outcomes. Flags blood type × condition combinations with unusually high concentration ratios.

**Key techniques:** `PARTITION BY "Blood Type"` proportional window, abnormal rate by blood group, concentration flagging.

---

## 🔑 Key Trends & Findings

- **Patient Demographics (Pediatrics):** Within the 0-17 age band, the top condition for females is Obesity (27.3% of pediatric female cases) which also shows a 26.7% abnormal rate. For males in the same age band, Cancer is the leading diagnosis (21.3%) with a surprisingly lower abnormal outcome rate of 23.1%. Asthma in pediatric females showed the highest alarming abnormal test rate at 60.0%. 4,102 patients (7.5%) are CRITICAL risk, all share the same profile: elderly (75+), emergency admission, abnormal test results, and long stays (26–30 days)
- **Repeat Patients & Chronicity:** Certain patients (e.g., David Munoz) exhibit significant health chronicity, presenting with 3 distinct admissions for Cancer and Diabetes across 138 days in the system, racking up $84,000 in lifetime billing. Repeat patients consistently skew towards high ongoing medical management. 4,973 patients were readmitted, max 3 times. Most same-condition readmissions, though some show multi-condition patterns (Cancer+Diabetes, Arthritis+Asthma, etc.).
- **Top Performing Doctors:** Doctor "Michael Smith" leads in volume with 27 patients treated, generating $784,000 in total revenue. However, his abnormal outcome rate is 44.4%. "Matthew Smith", treating slightly fewer patients (17), has a vastly lower abnormal rate of just 17.6%, reflecting potential variations in case complexity or efficiency.
- **Medication Effectiveness Proxies:** When examining condition-medication pairs, **Ibuprofen for Asthma** yielded the highest proportion of "Normal" test results (35.3%) and averaged roughly a 15.9-day stay. By contrast, Aspirin for Arthritis underperformed, with more frequent occurrences of "Abnormal" outcomes and lower "Normal" yield (31.5%).
- **Insurance Dominance:** "Aetna" and "Blue Cross" are the leading payers across chronic diseases. Aetna covers 1,862 matching Hypertension cases accounting for $48.1M in total lifetime billing, while Blue Cross leads Obesity interventions spanning 1,872 cases and $48.8M billed.
- **Seasonality of Admissions:** Late 2019 saw significant volume spikes, peaking in October 2019 with a 7.5% month-over-month growth (993 admissions pulling in $25.7M total billing). Month-over-month trends highlight fluctuating demands with predictable emergency case upticks entering the winter months. Monthly admissions are remarkably stable at around 900–1,000/month across 5 years with no seasonal spikes, no COVID dip. The only anomaly is the partial May 2024 cutoff. Emergency admissions hold steady at around 32–33%/year, with no escalation trend.
- **Absence of Billing Anomalies:** No individual claims breached the strictly defined "Outlier" threshold (> 2 Standard Deviations above the mean) when controlled for exactly the same Medical Condition and Admission Type, pointing towards remarkably consistent billing frameworks across all hospitals in the dataset. However, around 400 negative billing records exist which could indicate potential credits, adjustments, or data errors that need review.
- **Hospital Efficiency Variations:** "LLC Smith" tops hospital volume with 44 patients and a 15.5-day average length of stay (billing ~$1503 per day). Conversely, "Johnson Inc" processes patients notably faster (14.5-day LOS) but bills at an accelerated daily rate of ~$1891 per day.

---

## 🚀 How to Run the Full Pipeline

```bash
# 1. Set up your virtual environment and install dependencies
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install pandas sqlalchemy psycopg2-binary python-dotenv

# 2. Create your .env file with DB credentials

# 3. Create the table in PostgreSQL (run schema.sql via psql or pgAdmin)

# 4. Clean the raw data
cd src
python data_cleaning.py

# 5. Load cleaned data into the database
python load_data_to_db.py

# 6. Run insights in sql_queries.sql via psql, pgAdmin, or DBeaver
```

---

## 📌 Notes

- `Room Number` was deliberately excluded from the schema as it holds no analytical value.
- All credentials are managed via `.env` and should **never be committed to version control**. Add `.env` to your `.gitignore`.
- The dataset is **synthetic** — it does not contain real patient data and is intended for educational and analytical practice only.
