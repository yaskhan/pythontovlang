from pydantic import BaseModel, Field

class User(BaseModel):
    name: str = Field(min_length=2)
    age: int = Field(gt=0)
    email: str = 'unknown@example.com'
