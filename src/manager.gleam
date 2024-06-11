import database/process_commit
import gleam/erlang
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/intensity_tracker.{type IntensityTracker}

pub type PathToProcess {
  PathToProcess(id: String, pathname: String)
}

pub type Message {
  Shutdown
  GetFirstTask(client: Subject(Option(PathToProcess)))
  // CommitTask(
  //   result: PathProcessingResult,
  //   next_path: String,
  //   client: Subject(Option(PathToProcess)),
  // )
}

type PathProcessing {
  PathProcessing(path_id: String, processed_by: Int)
}

type PathProcessingResult {
  PathProcessingResult(path_id: String, json: String)
}

type State {
  State(rate_limiter: IntensityTracker, processing: List(PathProcessing))
}

fn handle_message(message: Message, state: State) -> actor.Next(Message, State) {
  let not_in = get_paths_being_processed(state)
  let state = State(..state, processing: not_in)

  let currently_processing_ids = not_in |> list.map(fn(item) { item.path_id })

  case message {
    Shutdown -> actor.Stop(process.Normal)
    GetFirstTask(client) -> {
      let can_take = intensity_tracker.add_event(state.rate_limiter)
      let next_path =
        process_commit.run(process_commit.Init(currently_processing_ids))

      case can_take, next_path {
        Ok(tracker), Ok(next_path) -> {
          process.send(
            client,
            Some(PathToProcess(next_path.path_id, next_path.path)),
          )
          let timeout = erlang.system_time(erlang.Second) + 60
          actor.continue(
            State(rate_limiter: tracker, processing: [
              PathProcessing(next_path.path_id, timeout),
              ..not_in
            ]),
          )
        }
        _, _ -> {
          process.send(client, None)
          actor.continue(State(..state, processing: not_in))
        }
      }
    }
    // CommitTask(result, next_path, client) -> {
    //   let can_take = intensity_tracker.add_event(state.rate_limiter)

    //   let next_path =
    //     process_commit.run(process_commit.Commit(
    //       path_id: result.path_id,
    //       json: result.json,
    //       next_enqueued_path: next_path,
    //       not_in: currently_processing_ids,
    //     ))
    // }
  }
}

fn get_paths_being_processed(state: State) {
  let current_time = erlang.system_time(erlang.Second)

  list.filter(state.processing, fn(path) { path.processed_by <= current_time })
}

pub fn start() {
  let rate_limiter = intensity_tracker.new(15, 1000)

  let assert Ok(actor) = actor.start(State(rate_limiter, []), handle_message)

  actor
}
