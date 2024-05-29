import argv
import gleam/erlang/os
import gleam/list
import gleam/result

pub opaque type Context {
  Context(stripe_sk: String)
}

pub fn new() -> Result(Context, String) {
  let args = argv.load().arguments

  use secret_key <- result.try(get_stripe_sk(args))

  Ok(Context(stripe_sk: secret_key))
}

fn get_stripe_sk(argv: List(String)) -> Result(String, String) {
  let arg =
    list.window_by_2(argv)
    |> list.find(fn(tuple) {
      case tuple {
        #("--stripe-sk", _) | #("--sk", _) | #("-sk", _) -> True
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
