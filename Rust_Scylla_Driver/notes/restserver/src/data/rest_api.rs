use serde::Deserialize;
use serde::Serialize;

#[derive(Serialize, Deserialize)]
pub struct AddNoteRequest {
    #[serde(default)]
    pub id: Option<String>,
    pub topic: String,
    pub content: String,
}

#[derive(Debug, Serialize)]
pub struct AppError {
    message: String,
}
