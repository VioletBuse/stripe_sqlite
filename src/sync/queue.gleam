import gleam/otp/actor
import gleam/erlang/process

pub type Message {
    Shutdown
}

pub type QueueItem {
    QueueItem(base_url: String)
}

type State {
    State(urls: List(QueueItem))
}

fn handle_message(message: Message, state: State) -> actor.Next(Message, State) {
    case message {
        Shutdown -> actor.Stop(process.Normal)
    }
}

pub fn start() {
    let assert Ok(actor) = actor.start(State(), handle_message)

    actor
}


