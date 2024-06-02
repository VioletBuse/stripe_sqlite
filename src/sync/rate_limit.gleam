import gleam/erlang/process.{type Selector, type Subject}

pub type Message {
  Shutdown
  Request(Subject(Result(Nil, Nil)))
}

type Action {
  Reset
}

pub fn start(limit: Int, link link: Bool) -> Result(Subject(Message), Nil) {
  let subject_receiver: Subject(Subject(Message)) = process.new_subject()

  process.start(fn() { init(limit, subject_receiver) }, link)

  process.receive(subject_receiver, 1000)
}

type State {
  State(internal_subject: Subject(Action), limit: Int, current: Int)
}

fn init(limit: Int, parent_subject: Subject(Subject(Message))) {
  let internal_subject: Subject(Action) = process.new_subject()
  let external_subject: Subject(Message) = process.new_subject()

  let state = State(internal_subject, limit, 0)

  process.send(parent_subject, external_subject)
  process.send_after(internal_subject, 1000, Reset)

  loop(state, internal_subject, external_subject)
}

fn loop(
  state: State,
  internal_subject: Subject(Action),
  external_subject: Subject(Message),
) {
  let selector: Selector(Result(State, process.ExitReason)) =
    process.new_selector()
    |> process.selecting(internal_subject, handle_action(_, state))
    |> process.selecting(external_subject, handle_message(_, state))

  case process.select_forever(selector) {
    Ok(new_state) -> loop(new_state, internal_subject, external_subject)
    Error(_) -> Nil
  }
}

fn handle_action(
  action: Action,
  state: State,
) -> Result(State, process.ExitReason) {
  case action {
    Reset -> {
      process.send_after(state.internal_subject, 1000, Reset)
      Ok(State(..state, current: 0))
    }
  }
}

fn handle_message(
  message: Message,
  _state: State,
) -> Result(State, process.ExitReason) {
  case message {
    Shutdown -> Error(process.Normal)
    Request(client) -> {
        case state.limit - state.current {
            difference if difference <= 0 -> {
                process.send(client, Error(Nil))
                Ok(state)
            }
            _ -> {
                process.send(client, Ok(Nil))
                Ok(State(..state, current: state.current + 1))
            }
        }
    }
  }
}
