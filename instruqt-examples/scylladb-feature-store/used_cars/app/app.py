import os, sys
from collections import OrderedDict
import uuid
import pickle
import pandas as pd
import streamlit as st

# Add parent directory to sys.path
parent_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.append(parent_dir)

from scylladb import ScyllaClient

st.set_page_config(layout="wide")

ALL_FEATURE_NAMES = ['year', 'mileage', 'tax', 'mpg', 'engine_size', 'model_A1', 'model_A2',
       'model_A3', 'model_A4', 'model_A5', 'model_A6', 'model_A7', 'model_A8',
       'model_Q2', 'model_Q3', 'model_Q5', 'model_Q7', 'model_Q8', 'model_R8',
       'model_RS3', 'model_RS4', 'model_RS5', 'model_RS6', 'model_RS7',
       'model_S3', 'model_S4', 'model_S5', 'model_S8', 'model_SQ5',
       'model_SQ7', 'model_TT', 'transmission_Automatic',
       'transmission_Manual', 'transmission_Semi-Auto', 'fuel_type_Diesel',
       'fuel_type_Hybrid', 'fuel_type_Petrol']
AUDI_MODELS = (
                "A1", "A2", "A3", "A4", "A5",
                "A6", "A7", "A8", "Q1", "Q2",
                "Q3", "Q4", "Q5", "Q6", "Q7",
                "Q8", "R8", "S3", "S4", "S5",
                "S8", "SQ5", "SQ7", "TT"
            )
FUEL_TYPES = (
    "Diesel",
    "Petrol",
    "Hybrid"
)
TRANSMISSION_TYPES = (
    "Manual",
    "Automatic"
)

client = ScyllaClient()
session = client.get_session()


# model = CreditScoringModel()
# if not model.is_model_trained():
#    raise Exception("The credit scoring model has not been trained. Please run `python run.py`.")


def get_user_input_features():
    with st.sidebar.form(key="car_features_form"):
        brand = st.selectbox("Brand", ["Audi"])
        car_model = st.selectbox("Model", AUDI_MODELS)
        fuel_type = st.selectbox("Fuel type", FUEL_TYPES)
        transmission = st.selectbox("Transmission", TRANSMISSION_TYPES)
        year = st.slider("Year", 1990, 2023, 2015, 1)
        mileage = st.slider("Mileage", 0, 300000, 50000, 10000)
        engine_size = st.slider("Engine size", 1.0, 4.0, 1.4, 0.1)
        mpg = st.slider("Miles Per Gallon", 0, 150, 50, 5)
        tax = st.slider("Tax", 0, 400, 140, 10)

        # Add a submit button
        submitted = st.form_submit_button("Submit")

    if submitted:
        raw_features = OrderedDict(
            {
                "car_id": uuid.uuid4(), # generate a new UUID for each car
                "brand": brand,
                "model": car_model,
                "year": year,
                "transmission": transmission,
                "fuel_type": fuel_type,
                "mpg": mpg,
                "engine_size": engine_size,
                "mileage": mileage,
                "tax": tax,
            }
        )
        insert_raw_features(raw_features)                
        return raw_features
    else:
        return None


def predict_price(transformed_features: OrderedDict):
    # Load the model
    with open('model/used_car_price.pkl', 'rb') as model_file:
        regressor = pickle.load(model_file)
    
    df = pd.DataFrame.from_dict([{item['feature_name']: item['feature_value'] for item in transformed_features}])
    df = df.drop(['brand'],axis=1)
    # MAKE SURE THE ORDER OF COLUMNS IS THE SAME AS DURING TRAINING
    df = df[ALL_FEATURE_NAMES] 
    
    # Make prediction
    return regressor.predict(df)

def insert_raw_features(raw_features: OrderedDict):
    feature_names = raw_features.keys()
    feature_values = raw_features.values()
    cql = f"""INSERT INTO raw_car_features ({','.join(feature_names)}) 
              VALUES ({','.join(['%s' for n in feature_names])})
           """
    session.execute(cql, feature_values)


def add_empty_features(encoded_features: OrderedDict):
    """Add empty features to the feature vector."""
    for feature_name in ALL_FEATURE_NAMES:
        if feature_name not in encoded_features:
            encoded_features[feature_name] = 0
    return encoded_features

def create_feature_vectors(raw_features: OrderedDict):
    df = pd.DataFrame.from_dict([raw_features])
    # One-hot encoding for categorical features
    one_hot_encoded_features = pd.get_dummies(df,columns=['model', 'transmission','fuel_type'])
    encoded_features_dict = OrderedDict(one_hot_encoded_features.to_dict(orient="records")[0])
    add_empty_features(encoded_features_dict)
    transformed_features = [
        OrderedDict({
            "car_id": encoded_features_dict["car_id"],
            "feature_name": key,
            "feature_value": value
        })
        for key, value in encoded_features_dict.items() if key != "car_id"
    ]
    insert_feature_vectors(transformed_features)
    return transformed_features


def insert_feature_vectors(transformed_features: list[OrderedDict]):
    """Insert feature vectors into the database."""
    cql = f"""INSERT INTO car_features (car_id, feature_name, feature_value) 
              VALUES (%s, %s, %s)
           """
    list_of_feature_vectors = [list(ordered_dict.values()) for ordered_dict in transformed_features]   
    for feature_vector in list_of_feature_vectors:
        serialized_vector = serialize_feature_vector(feature_vector)
        session.execute(cql, serialized_vector)
    
  
def serialize_feature_vector(feature_vector):
    """Convert feature vector to string for storage."""
    serialized_vector = []
    for feature_value in feature_vector:
        if isinstance(feature_value, (int, float, bool)):
            serialized_vector.append(serialize_feature_value(feature_value))
        elif isinstance(feature_value, str):
            serialized_vector.append(feature_value)
        elif isinstance(feature_value, uuid.UUID):
            serialized_vector.append(feature_value)
        else:
            raise ValueError(f"Unsupported type: {type(feature_value)}")
    return serialized_vector
      
def serialize_feature_value(value):
    """Convert Python value to string for storage."""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)

def deserialize_feature_value(value_str, expected_type):
    """Convert string back to Python value of expected type."""
    try:
        if expected_type == int:
            return int(value_str)
        elif expected_type == float:
            return float(value_str)
        elif expected_type == bool:
            return value_str.lower() == "true"
        elif expected_type == str:
            return value_str
        else:
            raise ValueError(f"Unsupported type: {expected_type}")
    except Exception as e:
        raise ValueError(f"Failed to cast '{value_str}' to {expected_type}: {e}")



# Application
col1, col2 = st.columns([2, 1])
with col1:
    st.title("Used car price prediction")
    st.write(
        "This application predicts the price of a used car based on its features. "
        "The model is trained on a dataset of used car advertisements and uses features such as engine, fuel type, transmission, mileage, model, and year."
    )
with col2:
    st.image("app/images/audi.jpg", width=300)

# Feature input by user
st.header("User input:")
car_features = get_user_input_features()
df = pd.DataFrame.from_dict([car_features])
print(df)
if 'car_id' in df.columns:
    df_user_input = df.drop(['car_id'],axis=1)
    df_user_input
else:
    st.error("Please submit the car features in the sidebar!")
    st.stop()
    



# Full feature vector
st.header("Full feature vector:")
feature_vectors = create_feature_vectors(car_features)
df = pd.DataFrame.from_dict(feature_vectors)
pivoted_df = df.pivot(index="car_id", columns="feature_name", values="feature_value").reset_index()
pivoted_df

# Full feature vector
st.header("Full feature vector (as stored in the database):")
st.write(
    "Query:\n",
    f"`SELECT * FROM feature_store.car_features WHERE car_id = {df.loc[0, 'car_id']};`",
)
df
  


# Results of prediction
st.header("Model prediction:")
result = predict_price(feature_vectors)
st.header(str(int(result)) + " GBP")
