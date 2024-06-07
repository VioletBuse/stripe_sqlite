import gleam/erlang
import gleam/io
import gleam/result
import sqlight
import storch

pub fn migrate(connection: sqlight.Connection) {
  let assert Ok(priv_dir) = erlang.priv_directory("stripe_sqlite")
  use migrations <- result.try(storch.get_migrations(priv_dir <> "/migrations"))
  storch.migrate(migrations, connection)
}

pub fn main() {
  use connection <- sqlight.with_connection("file:/tmp/test.db")
  let res = migrate(connection)
  io.debug(res)
}
