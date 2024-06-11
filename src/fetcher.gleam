import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Subject}
import gleam/http.{type Header}
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri
import httpp/send
import jackson
import stripe_config

pub type StripeResourceRequest {
  StripeResourceRequest(
    base_resource_url: String,
    starting_after: Option(String),
  )
}

pub type StripeResourceResponse {
  StripeResourseResponse(
    object_type: String,
    values: List(String),
    has_more: Bool,
  )
}

pub type StripeResourceFetchError {
  HttpClientError(Dynamic)
  JsonParseError
  InvalidListResponse
  BadRequest
  Unauthorized
  RequestFailed
  Forbidden
  NotFound
  Conflict
  TooManyRequests
  InternalServerError
}

// pub fn start_fetcher(manager: Subject())

type StripeListObject {
  StripeListObject(url: String, has_more: Bool, values: List(Dynamic))
}

fn fetch_stripe_list(
  resource: StripeResourceRequest,
  stripe_config: stripe_config.StripeConfig,
) -> Result(StripeResourceResponse, StripeResourceFetchError) {
  let assert Ok(uri) = uri.parse("https://api.stripe.com")
  let assert Ok(req) = request.from_uri(uri)

  let query_params = case resource.starting_after {
    Some(after) -> [#("starting_after", after)]
    None -> []
  }

  let req =
    req
    |> request.set_path(resource.base_resource_url)
    |> request.set_query(query_params)
    |> request.set_header(
      "authorization",
      "Bearer: " <> stripe_config.secret_key,
    )

  let res =
    send.send(req)
    |> result.map_error(dynamic.from)
    |> result.map_error(HttpClientError)

  use response <- result.try(res)

  use <- bool.guard(
    when: response.status >= 400,
    return: Error(status_code_to_error(response.status)),
  )

  use parsed <- result.try(
    jackson.parse(response.body) |> result.map_error(fn(_) { JsonParseError }),
  )

  use decoded <- result.try(
    jackson.decode(
      parsed,
      dynamic.decode3(
        StripeListObject,
        dynamic.field("url", dynamic.string),
        dynamic.field("has_more", dynamic.bool),
        dynamic.field("data", dynamic.list(dynamic.dynamic)),
      ),
    )
    |> result.map_error(fn(_) { InvalidListResponse }),
  )

  let entries =
    decoded.values
    |> list.map(jackson.dynamic_to_json)
    |> list.map(result.map(_, jackson.to_string))
  let entries = result.all(entries)

  use entries <- result.try(
    entries |> result.map_error(fn(_) { InvalidListResponse }),
  )

  Ok(StripeResourseResponse(decoded.url, entries, decoded.has_more))
}

fn status_code_to_error(status: Int) -> StripeResourceFetchError {
  case status {
    400 -> BadRequest
    401 -> Unauthorized
    402 -> RequestFailed
    403 -> Forbidden
    404 -> NotFound
    409 -> Conflict
    429 -> TooManyRequests
    500 | 502 | 503 | 504 -> InternalServerError
    _ ->
      HttpClientError(
        dynamic.from(#("tried to turn status to error: ", status)),
      )
  }
}
