import gleam/dynamic
import gleam/erlang
import gleam/int
import gleam/result
import sqlight.{type Connection}
import storch

pub fn with_database(function: fn(Connection) -> Result(a, b)) -> Result(a, b) {
  use connection <- sqlight.with_connection("./stripe.db")

  let _ = sqlight.exec("begin transaction;", connection)
  let result = function(connection)
  let _ = case result {
    Ok(_) -> sqlight.exec("commit transaction;", connection)
    Error(_) -> sqlight.exec("rollback;", connection)
  }

  result
}

pub fn migrate() {
  use connection <- sqlight.with_connection("./stripe.db")

  use priv_dir <- result.try(
    erlang.priv_directory("stripe_sqlite")
    |> result.map_error(fn(_) { storch.DirectoryNotExist("priv directory") }),
  )
  let path = priv_dir <> "/migrations"

  use migrations <- result.try(storch.get_migrations(path))
  storch.migrate(migrations, connection)
}
