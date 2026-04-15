import os 
from dotenv import load_dotenv
from sqlalchemy import create_engine 

def get_db_engine(): 
    # Load the enviroment variables from .env file
    load_dotenv() 

    # Retrieve variables
    db_user = os.getenv("DB_USER")
    db_password = os.getenv("DB_PASSWORD")
    db_host = os.getenv("DB_HOST")
    db_port = os.getenv("DB_PORT")
    db_name = os.getenv("DB_NAME")

    # Handle mission variables 
    if not all([db_user, db_password, db_host, db_port, db_name]):
        raise ValueError("Missing database configuration. Please check your .env file.")

    # Construct the SQLAlchemy Database URI 
    db_url = f"postgresql+psycopg2://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"

    # Create and return SQLAlchemy engine
    engine = create_engine(db_url, echo = False)

    return engine 

# Test the connection
if __name__ == "__main__":
    try:
        engine = get_db_engine()
        with engine.connect() as conn:
            print("Successfully connected to the database!")
    except Exception as e:
        print(f"Error connecting to the database: {e}")


    