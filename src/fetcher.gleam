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

pub fn start_fetch_task(
  request: StripeResourceRequest,
  config: stripe_config.StripeConfig,
  response_subject: Subject(
    Result(StripeResourceResponse, StripeResourceFetchError),
  ),
) {
  process.start(
    fn() {
      let result = fetch_stripe_list(request, config)
      process.send(response_subject, result)
    },
    True,
  )

  Nil
}

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
    last_id: Option(String),
  )
}

pub type StripeResourceFetchError {
  HttpClientError(Dynamic)
  JsonParseError
  InvalidListResponse
  InvalidDataObjectValues
  BadRequest
  Unauthorized
  RequestFailed
  Forbidden
  NotFound
  Conflict
  TooManyRequests
  InternalServerError
}

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

  let object_type =
    decoded.values
    |> list.map(dynamic.field("object", dynamic.string))
    |> result.all
    |> result.nil_error
    |> result.map(list.unique)
    |> result.try(fn(list) {
      case list {
        [object_type] -> Ok(object_type)
        _ -> Error(Nil)
      }
    })

  use object_type <- result.try(
    object_type |> result.map_error(fn(_) { InvalidDataObjectValues }),
  )

  let last_data_id =
    decoded.values
    |> list.last
    |> result.map(dynamic.field("id", dynamic.string))
    |> result.map(result.nil_error)
    |> result.flatten
    |> option.from_result

  Ok(StripeResourseResponse(
    object_type: object_type,
    values: entries,
    has_more: decoded.has_more,
    last_id: last_data_id,
  ))
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
