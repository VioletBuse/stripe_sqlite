import database
import gleam/dynamic
import gleam/erlang
import gleam/int
import gleam/list
import gleam/result
import sqlight

pub type CommitResult {
  CommitResult(path_id: String, path: String)
}

pub type CommitRequest {
  Init(not_in: List(String))
  Commit(path_id: String, json: String, next_enqueued_path: String)
}

pub fn run(request: CommitRequest) -> Result(CommitResult, Nil) {
  use connection <- database.with_database

  case request {
    Init(not_in) -> {
      let to_fetch =
        sqlight.query(
          "SELECT (id, path) FROM paths WHERE to_fetch = 1 ORDER BY created_at ASC;",
          connection,
          [],
          dynamic.tuple2(dynamic.string, dynamic.string),
        )

      let to_fetch =
        result.map(to_fetch, list.filter(_, fn(row: #(String, String)) {
          list.contains(not_in, row.0)
        }))

      case to_fetch {
        Error(_) -> Error(Nil)
        Ok([#(id, path), ..]) -> Ok(CommitResult(id, path))
        Ok([]) -> {
          let timestamp = erlang.system_time(erlang.Second)
          let id = int.random(1_000_000_000) |> int.to_base36
          let new_path =
            sqlight.query(
              "INSERT INTO paths (id, path, to_fetch, created_at) VALUES (?,?,?,?) RETURNING *;",
              connection,
              [
                sqlight.text(id),
                sqlight.text("/events"),
                sqlight.bool(True),
                sqlight.int(timestamp),
              ],
              dynamic.tuple4(
                dynamic.string,
                dynamic.string,
                dynamic.int,
                dynamic.int,
              ),
            )

          case new_path {
            Ok([#(id, path, _, _)]) -> Ok(CommitResult(id, path))
            _ -> Error(Nil)
          }
        }
      }
    }
    Commit(path_id, resulting_json, next_path) -> {
      use _ <- result.try(
        sqlight.query(
          "UPDATE paths SET to_fetch = 1 WHERE id = ?;",
          connection,
          [sqlight.text(path_id)],
          dynamic.dynamic,
        )
        |> result.nil_error,
      )

      let id = int.random(1_000_000_000) |> int.to_base36
      let timestamp = erlang.system_time(erlang.Second)

      use _ <- result.try(
        sqlight.query(
          "INSERT INTO path_fetch_results (id, json, path_id, fetched_at) VALUES (?,?,?,?);",
          connection,
          [
            sqlight.text(id),
            sqlight.text(resulting_json),
            sqlight.text(path_id),
            sqlight.int(timestamp),
          ],
          dynamic.dynamic,
        )
        |> result.nil_error,
      )

      let id = int.random(1_000_000_000) |> int.to_base36

      use _ <- result.try(
        sqlight.query(
          "INSERT INTO paths (id, path, to_fetch, created_at) VALUES (?,?,?,?);",
          connection,
          [
            sqlight.text(id),
            sqlight.text(next_path),
            sqlight.bool(True),
            sqlight.int(timestamp),
          ],
          dynamic.dynamic,
        )
        |> result.nil_error,
      )

      use next_path <- result.try(
        sqlight.query(
          "SELECT (id, path) FROM paths WHERE to_fetch = 1 ORDER BY created_at ASC;",
          connection,
          [],
          dynamic.tuple2(dynamic.string, dynamic.string),
        )
        |> result.nil_error,
      )

      case next_path {
        [] -> Error(Nil)
        [#(id, path), ..] -> Ok(CommitResult(id, path))
      }
    }
  }
}
