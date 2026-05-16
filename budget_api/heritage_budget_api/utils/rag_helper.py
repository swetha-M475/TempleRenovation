import json
import os
import chromadb
from chromadb.utils import embedding_functions

# Load knowledge base files
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_knowledge_base():
    with open(os.path.join(BASE_DIR, "knowledge_base", "district_rates.json")) as f:
        district_rates = json.load(f)
    with open(os.path.join(BASE_DIR, "knowledge_base", "work_types.json")) as f:
        work_types = json.load(f)
    return district_rates, work_types

# Initialize ChromaDB
chroma_client = chromadb.Client()
embedding_fn = embedding_functions.SentenceTransformerEmbeddingFunction(
    model_name="all-MiniLM-L6-v2"
)

collection = chroma_client.get_or_create_collection(
    name="heritage_rates",
    embedding_function=embedding_fn
)

def setup_chromadb():
    district_rates, work_types = load_knowledge_base()

    documents = []
    ids = []
    metadatas = []

    # Add district rate chunks
    for district, rates in district_rates.items():
        for work, rate in rates.items():
            text = f"{district} district {work.replace('_', ' ')} rate is {rate}"
            documents.append(text)
            ids.append(f"{district}_{work}")
            metadatas.append({"district": district, "work_type": work})

    # Add work type chunks
    for work, details in work_types.items():
        text = f"{work.replace('_', ' ')}: {details['description']}. Keywords: {', '.join(details['keywords'])}. Materials: {details['materials']}. Labor days: {details['labor_days']}"
        documents.append(text)
        ids.append(f"work_{work}")
        metadatas.append({"type": "work_description"})

    # Add to ChromaDB only if empty
    if collection.count() == 0:
        collection.add(documents=documents, ids=ids, metadatas=metadatas)
        print("✅ ChromaDB knowledge base loaded successfully!")
    else:
        print("✅ ChromaDB already loaded!")

def fetch_district_rates(district: str, work_description: str):
    # Search ChromaDB with district + work description
    query = f"{district} district {work_description}"
    results = collection.query(
        query_texts=[query],
        n_results=10,
        where={"district": district}
    )
    return results["documents"][0] if results["documents"] else []

def get_work_details(work_description: str):
    # Search work types based on description
    results = collection.query(
        query_texts=[work_description],
        n_results=3,
        where={"type": "work_description"}
    )
    return results["documents"][0] if results["documents"] else []
