use serde::Deserialize;
use serde::Serialize;
use uuid::Uuid;

use crate::db::model::DbNote;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Note {
    pub id: Uuid,
    pub content: String,
    //    #[serde(rename = "type")]
    pub topic: String,
}

impl Note {
    pub fn new(id: Uuid, topic: String, content: String) -> Self {
        Self { id, topic, content }
    }

    pub fn from(db_entries: Vec<DbNote>) -> Option<Note> {
        let n = db_entries.get(0)?;
        let note = Note::new(n.id, n.content.clone(), n.topic.clone());

        Some(note)
    }

    pub fn from_all(db_entries: Vec<DbNote>) -> Vec<Note> {
        let mut notes = vec![];
        for note in db_entries {
            let data = Note::new(note.id, note.topic.clone(), note.content.clone());
            notes.push(data)
        }
        notes
    }
}
