import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/intensity_tracker.{type IntensityTracker}

pub type Message {
  Shutdown
}

type State {
  State(rate_limiter: IntensityTracker)
}

fn handle_message(message: Message, state: State) -> actor.Next(Message, State) {
  case message {
    Shutdown -> actor.Stop(process.Normal)
  }
}

pub fn start() {
  let rate_limiter = intensity_tracker.new(15, 1000)

  let assert Ok(actor) = actor.start(State(rate_limiter), handle_message)

  actor
}
