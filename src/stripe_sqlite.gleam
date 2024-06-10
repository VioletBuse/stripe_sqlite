import database
import gleam/result

pub fn main() {
  use _ <- result.try(database.migrate())

  Ok(Nil)
}
