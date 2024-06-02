import gleam/erlang
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/otp/actor
import ids/nanoid

pub type Message {
  Shutdown
  AddRequestUrl(path: String)
  GetRequestUrl(Subject(Result(RequestUrl, Nil)))
  MarkCompleted(url_id: String)
}

pub type RequestUrlStatus {
  NotProcessed
  Processing(since: Int)
  Completed
}

pub type RequestUrl {
  RequestUrl(id: String, status: RequestUrlStatus, created: Int, path: String)
}

type State {
  State(
    request_urls: List(RequestUrl),
    rate_limit: Int,
    current_count: Int,
    last_reset_time: Int,
  )
}

fn handle_message(message: Message, state: State) -> actor.Next(Message, State) {
  let current_time = erlang.system_time(erlang.Millisecond)

  case message {
    Shutdown -> actor.Stop(process.Normal)
    AddRequestUrl(path) -> {
      let new_url = RequestUrl(nanoid.generate(), NotProcessed, current_time, path)
      actor.continue(
        State(
          ..state,
          request_urls: update_request_urls([new_url, ..state.request_urls]),
        ),
      )
    }
    GetRequestUrl(client) -> {
      let #(response, next_state) = case
        state.request_urls,
        current_time
        - state.last_reset_time,
        state.rate_limit
        - state.current_count
      {
        [], _, _ -> #(Error(Nil), state)
        [next_request, ..rest], _, rate_limit_difference
          if rate_limit_difference > 0
        -> #(
          Ok(next_request),
          State(..state, request_urls: update_request_urls(rest)),
        )
        [next_request, ..rest], reset_time_difference, _
          if reset_time_difference > 1000
        -> #(
          Ok(next_request),
          State(
            ..state,
            request_urls: update_request_urls(rest),
            last_reset_time: current_time,
            current_count: 1,
          ),
        )
        _, _, _ -> #(Error(Nil), state)
      }

      process.send(client, response)
      actor.continue(next_state)
    }
    MarkCompleted(request_url_id) -> actor.continue(State(..state, request_urls: mark_url_completed(state.request_urls, request_url_id)))
  }
}

fn update_request_urls(urls: List(RequestUrl)) -> List(RequestUrl) {
  let current_time = erlang.system_time(erlang.Millisecond)

  list.filter_map(urls, fn(url) {
    case url {
      RequestUrl(status: NotProcessed, ..) -> Ok(url)
      RequestUrl(status: Processing(since), ..) -> {
        case current_time - since {
          difference if difference > 60_000 ->
            Ok(RequestUrl(..url, status: NotProcessed))
          _ -> Ok(url)
        }
      }
      RequestUrl(status: Completed, ..) -> Error(Nil)
    }
  })
  |> list.sort(by: fn(url_1, url_2) {
    int.compare(url_1.created, url_2.created)
  })
}

fn mark_url_completed(urls: List(Request_Url), id: String) -> List(RequestUrl) {
    list.map(urls, fn (url) {
        case url.id == id {
            True -> RequestUrl(..url, status: Completed)
            False -> url
        }
    })
}
