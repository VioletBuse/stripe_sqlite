import fetch_resource.{type StripeResourceResponse}
import gleam/dynamic
import gleam/erlang
import gleam/list
import gleam/option.{type Option}
import gleam/result
import jackson
import sqlight.{type Connection}

pub fn handle_fetch_result(
  result: StripeResourceResponse,
) -> Result(#(fn(Connection) -> Result(Nil, Nil), Option(String)), String) {
  let db_op = case result.object_type {
    "event" ->
      list.map(result.values, handle_event)
      |> result.all
      |> result.map(apply_db_ops)
    obj_type -> Error("We cannot handle the " <> obj_type <> " stripe type")
  }

  let cursor = case result.object_type {
    "event" -> {
      let vals =
        list.map(result.values, fn(val: String) {
          use json <- result.try(jackson.parse(val) |> result.nil_error)
          use dynamic <- result.try(
            jackson.decode(json, dynamic.dynamic) |> result.nil_error,
          )
          use id <- result.try(
            dynamic.field("id", dynamic.string)(dynamic) |> result.nil_error,
          )
          use created_at <- result.try(
            dynamic.field("created", dynamic.int)(dynamic) |> result.nil_error,
          )

          Ok(#(id, created_at))
        })

      let current_time = erlang.system_time(erlang.Second)

      result.all(vals)
      |> result.map(list.filter(_, fn(v: #(String, Int)) {
        v.1 < current_time - 5
      }))
      |> result.map(list.last)
      |> result.flatten
      |> result.map(fn(v) { v.0 })
      |> result.map_error(fn(_) { "could not parse cursor" })
    }
    _ -> result.last_id |> option.to_result("No cursor provided")
  }

  case db_op, cursor {
    Ok(op), Ok(cursor) -> Ok(#(op, option.Some(cursor)))
    Ok(op), _ -> Ok(#(op, result.request.starting_after))
    Error(internal), _ -> Error(internal)
  }
}

fn handle_event(
  event: String,
) -> Result(fn(Connection) -> Result(Nil, Nil), String) {
  todo
}

fn apply_db_ops(
  ops: List(fn(Connection) -> Result(Nil, Nil)),
) -> fn(Connection) -> Result(Nil, Nil) {
  case ops {
    [] -> fn(_) { Ok(Nil) }
    [next_op, ..rest] -> fn(conn: Connection) {
      use _ <- result.try(next_op(conn))
      apply_db_ops(rest)(conn)
    }
  }
}
