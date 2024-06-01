import argv
import gleam/erlang/os
import gleam/int
import gleam/list
import gleam/result

pub opaque type Context {
  Context(stripe_sk: String, rate_limit: Int)
}

pub fn context() -> Result(Context, String) {
  let args = argv.load().arguments

  use secret_key <- result.try(get_stripe_sk(args))
  use rate_limit <- result.try(get_rate_limit(args))

  Ok(Context(stripe_sk: secret_key, rate_limit: rate_limit))
}

fn get_stripe_sk(argv: List(String)) -> Result(String, String) {
  let arg =
    list.window_by_2(argv)
    |> list.find(fn(tuple) {
      case tuple {
        #("--stripe-sk", _) | #("--sk", _) | #("-s", _) -> True
        _ -> False
      }
    })

  let env = os.get_env("STRIPE_SECRET_KEY")

  case arg, env {
    Ok(#(_, secret_key)), _ -> Ok(secret_key)
    _, Ok(secret_key) -> Ok(secret_key)
    Error(_), Error(_) ->
      Error(
        "Stripe Secret Key not provided. Pass it through --stripe-sk, --sk, or with the $STRIPE_SECRET_KEY environment variable",
      )
  }
}

fn get_rate_limit(argv: List(String)) -> Result(Int, String) {
  let arg =
    list.window_by_2(argv)
    |> list.find(fn(tuple) {
      case tuple {
        #("--rate-limit", _) | #("--rl", _) | #("-r", _) -> True
        _ -> False
      }
    })
    |> result.try(fn(tuple) { int.parse(tuple.1) })

  let env =
    os.get_env("STRIPE_SYNC_RATE_LIMIT")
    |> result.try(int.parse)

  case arg, env {
    Ok(rate_limit), _ -> Ok(rate_limit)
    _, Ok(rate_limit) -> Ok(rate_limit)
    Error(_), Error(_) -> Ok(5)
  }
}
