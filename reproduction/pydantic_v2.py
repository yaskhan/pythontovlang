from pydantic import BaseModel, Field, field_validator, model_validator, computed_field, ConfigDict
from typing import Annotated

class User(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    name: Annotated[str, Field(min_length=2, max_length=50)]
    email: str

    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if '@' not in v:
            raise ValueError('Invalid email')
        return v.lower()

    @computed_field
    @property
    def display_name(self) -> str:
        return f"{self.name} <{self.email}>"
