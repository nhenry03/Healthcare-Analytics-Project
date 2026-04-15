import pandas as pd 

def load_and_clean_data(filepath: str) -> pd.DataFrame:
    """Load and clean data"""

    # Load data
    df = pd.read_csv(filepath)

    # Remove unneccesary column
    df.drop(columns=["Room Number"], inplace=True)

    # Delete duplicate rows
    df.drop_duplicates(inplace=True)

    # Convert column to appropriate data type
    df['Name'] = df['Name'].astype(str)
    df['Age'] = df['Age'].astype(int)
    df['Gender'] = df['Gender'].astype(str)
    df['Blood Type'] = df['Blood Type'].astype(str)
    df['Medical Condition'] = df['Medical Condition'].astype(str)
    df['Date of Admission'] = pd.to_datetime(df['Date of Admission'])
    df['Doctor'] = df['Doctor'].astype(str)
    df['Hospital'] = df['Hospital'].astype(str)
    df['Insurance Provider'] = df['Insurance Provider'].astype(str)
    df['Billing Amount'] = df['Billing Amount'].astype(float)
    df['Admission Type'] = df['Admission Type'].astype(str)
    df['Discharge Date'] = pd.to_datetime(df['Discharge Date'])
    df['Medication'] = df['Medication'].astype(str)
    df['Test Results'] = df['Test Results'].astype(str)

    return df

if __name__ == "__main__":
    RAW_PATH = "../data/raw/healthcare_dataset.csv"
    CLEANED_PATH = "../data/clean/cleaned_healthcare_data.csv"

    cleaned_data = load_and_clean_data(RAW_PATH)
    cleaned_data.to_csv(CLEANED_PATH, index=False)
    print(f"Cleaned data saved to {CLEANED_PATH}")