from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """애플리케이션 설정"""

    # Server
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    environment: str = "development"

    # OpenAI
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"

    # Firebase
    firebase_project_id: str = "swim-training-app-fe08f"
    firebase_credentials_path: str = "./firebase-credentials.json"

    # RAG
    chroma_persist_dir: str = "./data/chroma_db"

    # CORS
    allowed_origins: list[str] = ["*"]

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
    }


@lru_cache()
def get_settings() -> Settings:
    return Settings()
