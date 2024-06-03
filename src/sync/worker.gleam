import gleam/otp/actor

type Message

type State {
  State
}

pub fn spec() -> actor.Spec {
  actor.Spec(init: init_fn, init_timeout: 1000, loop: loop_fn)
}

fn init_fn() -> actor.InitResult {
  todo
}

fn loop_fn(message: Message, state: State) -> actor.Next(Message, State) {
  todo
}
