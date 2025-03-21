use scylla::DeserializeRow;
use uuid::Uuid;

#[derive(Default, Debug, Clone, DeserializeRow)]
pub struct DbNote {
    pub id: Uuid,
    pub content: String,
    //order here is important for "into_typed" - it has to be PK, CK and alphabetically ordered non PK/CK columns
    pub topic: String,
}

impl DbNote {}
