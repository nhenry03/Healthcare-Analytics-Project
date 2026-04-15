import pandas as pd
from utils import get_db_engine

def load_data_to_db():

    # Get connection engine
    engine = get_db_engine()

    # Load cleaned data
    df = pd.read_csv("../data/clean/cleaned_healthcare_data.csv")

    # Load data to database
    table_name = "healthcare_data"
    df.to_sql(table_name, engine, if_exists="append", index=False)

    print(f"Succesfully loaded data into {table_name} table.")

if __name__ == "__main__":
    load_data_to_db()