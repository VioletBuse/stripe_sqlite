import gleam/bool.{guard}
import gleam/dynamic.{
  type DecodeErrors, type Dynamic, DecodeError, bool, dynamic, field, int, list,
  string,
}
import gleam/list
import gleam/option.{type Option}
import gleam/result.{try}
import gleam/string
import stripe/types.{
  type StripeAddress, type StripeData, type StripeRecurring, type StripeShipping,
  type StripeTimestamp,
}

fn nullable_field(
  named name: a,
  of inner_type: fn(Dynamic) -> Result(b, DecodeErrors),
) -> fn(Dynamic) -> Result(Option(b), DecodeErrors) {
  fn(dyn: Dynamic) -> Result(Option(b), DecodeErrors) {
    dynamic.any([
      fn(dyn) {
        result.map(
          dynamic.optional_field(name, dynamic.optional(inner_type))(dyn),
          option.flatten,
        )
      },
    ])(dyn)
  }
}

fn string_enum(
  zipped: List(#(String, a)),
) -> fn(Dynamic) -> Result(a, DecodeErrors) {
  fn(dyn: Dynamic) -> Result(a, DecodeErrors) {
    use dyn_str <- try(string(dyn))

    let expected_values = list.map(zipped, fn(x) { x.0 })

    case list.find(zipped, fn(zip) { zip.0 == dyn_str }) {
      Ok(#(_, enum)) -> Ok(enum)
      Error(_) ->
        Error([
          DecodeError(
            expected: "One of" <> string.join(expected_values, ", "),
            found: dyn_str,
            path: [],
          ),
        ])
    }
  }
}

fn guard_object_type(
  json obj: Dynamic,
  of of: String,
  otherwise alternative: fn() -> Result(a, DecodeErrors),
) -> Result(a, DecodeErrors) {
  use object_type <- try(field("object", string)(obj))
  guard(
    when: object_type != of,
    return: Error([
      DecodeError(expected: of, found: object_type, path: ["object"]),
    ]),
    otherwise: alternative,
  )
}

fn stripe_address(json obj: Dynamic) -> Result(StripeAddress, DecodeErrors) {
  let city = nullable_field("city", string)
  let country = nullable_field("country", string)
  let line1 = nullable_field("line1", string)
  let line2 = nullable_field("line2", string)
  let postal_code = nullable_field("postal_code", string)
  let state = nullable_field("state", string)

  use city <- try(city(obj))
  use country <- try(country(obj))
  use line1 <- try(line1(obj))
  use line2 <- try(line2(obj))
  use postal_code <- try(postal_code(obj))
  use state <- try(state(obj))

  Ok(types.StripeAddress(obj, city, country, line1, line2, postal_code, state))
}

fn stripe_shipping(json obj: Dynamic) -> Result(StripeShipping, DecodeErrors) {
  let address = field("address", stripe_address)
  let name = field("name", string)
  let phone = nullable_field("phone", string)

  use address <- try(address(obj))
  use name <- try(name(obj))
  use phone <- try(phone(obj))

  Ok(types.StripeShipping(json: obj, address: address, name: name, phone: phone))
}

fn stripe_timestamp(json obj: Dynamic) -> Result(StripeTimestamp, DecodeErrors) {
  dynamic.any([dynamic.decode1(types.IntTimestamp, int)])(obj)
}

fn stripe_recurring(json obj: Dynamic) -> Result(StripeRecurring, DecodeErrors) {
  let aggregate_usage =
    field(
      "aggregate_usage",
      string_enum([
        #("last_during_period", types.LastDuringPeriod),
        #("last_ever", types.LastEver),
        #("max", types.Max),
        #("sum", types.Sum),
      ]),
    )
  let interval =
    field(
      "interval",
      string_enum([
        #("day", types.Day),
        #("week", types.Week),
        #("month", types.Month),
        #("year", types.Year),
      ]),
    )
  let interval_count = field("interval_count", int)
  let meter = nullable_field("meter", string)
  let usage_type =
    field(
      "usage_type",
      string_enum([#("metered", types.Metered), #("licensed", types.Licensed)]),
    )

  use aggregate_usage <- try(aggregate_usage(obj))
  use interval <- try(interval(obj))
  use interval_count <- try(interval_count(obj))
  use meter <- try(meter(obj))
  use usage_type <- try(usage_type(obj))

  Ok(types.StripeRecurring(
    json: obj,
    aggregate_usage: aggregate_usage,
    interval: interval,
    interval_count: interval_count,
    meter: meter,
    usage_type: usage_type,
  ))
}

pub fn stripe_event(json obj: Dynamic) -> Result(StripeData, DecodeErrors) {
  use <- guard_object_type(obj, "event")

  let id = field("id", string)
  let event_type = field("type", string)
  let account = nullable_field("account", string)
  let api_version = field("api_version", string)
  let created = field("created", stripe_timestamp)
  let data = field("data", field(named: "object", of: stripe_data))
  let livemode = field("livemode", bool)

  use id <- try(id(obj))
  use event_type <- try(event_type(obj))
  use account <- try(account(obj))
  use api_version <- try(api_version(obj))
  use created <- try(created(obj))
  use data <- try(data(obj))
  use livemode <- try(livemode(obj))

  Ok(types.Event(
    id: id,
    event_type: event_type,
    json: obj,
    account: account,
    api_version: api_version,
    created: created,
    data: data,
    livemode: livemode,
  ))
}

pub fn stripe_customer(json obj: Dynamic) -> Result(StripeData, DecodeErrors) {
  use <- guard_object_type(obj, "customer")

  let id = field("id", string)
  let address = nullable_field("address", stripe_address)
  let description = nullable_field("description", string)
  let email = nullable_field("email", string)
  let metadata = field("metadata", dynamic.dynamic)
  let name = nullable_field("name", string)
  let phone = nullable_field("phone", string)
  let shipping = nullable_field("shipping", stripe_shipping)
  let created = field("created", stripe_timestamp)
  let livemode = field("livemode", bool)
  let delinquent = nullable_field("delinquent", bool)
  let balance = field("balance", int)
  let currency = nullable_field("currency", string)

  use id <- try(id(obj))
  use address <- try(address(obj))
  use description <- try(description(obj))
  use email <- try(email(obj))
  use metadata <- try(metadata(obj))
  use name <- try(name(obj))
  use phone <- try(phone(obj))
  use shipping <- try(shipping(obj))
  use created <- try(created(obj))
  use livemode <- try(livemode(obj))
  use delinquent <- try(delinquent(obj))
  use balance <- try(balance(obj))
  use currency <- try(currency(obj))

  Ok(types.Customer(
    id: id,
    json: obj,
    address: address,
    description: description,
    email: email,
    metadata: metadata,
    name: name,
    phone: phone,
    shipping: shipping,
    created: created,
    livemode: livemode,
    delinquent: delinquent,
    balance: balance,
    currency: currency,
  ))
}

pub fn stripe_product(json obj: Dynamic) -> Result(StripeData, DecodeErrors) {
  use <- guard_object_type(obj, "product")

  let id = field("id", string)
  let active = field("active", bool)
  let default_price = nullable_field("default_price", string)
  let description = nullable_field("description", string)
  let metadata = field("metadata", dynamic.dynamic)
  let name = field("name", string)
  let created = field("created", stripe_timestamp)
  let images = field("images", list(string))
  let livemode = field("livemode", bool)
  let updated = field("updated", stripe_timestamp)
  let url = nullable_field("url", string)

  use id <- try(id(obj))
  use active <- try(active(obj))
  use default_price <- try(default_price(obj))
  use description <- try(description(obj))
  use metadata <- try(metadata(obj))
  use name <- try(name(obj))
  use created <- try(created(obj))
  use images <- try(images(obj))
  use livemode <- try(livemode(obj))
  use updated <- try(updated(obj))
  use url <- try(url(obj))

  Ok(types.Product(
    id: id,
    json: obj,
    active: active,
    default_price: default_price,
    description: description,
    metadata: metadata,
    name: name,
    created: created,
    images: images,
    livemode: livemode,
    updated: updated,
    url: url,
  ))
}

pub fn stripe_price(json obj: Dynamic) -> Result(StripeData, DecodeErrors) {
  use <- guard_object_type(obj, "price")

  let id = field("id", string)
  let active = field("active", bool)
  let currency = field("currency", string)
  let metadata = field("metadata", dynamic.dynamic)
  let nickname = nullable_field("nickname", string)
  let product =
    dynamic.any([
      field("product", string),
      field("product", field("id", string)),
    ])
  let recurring = nullable_field("recurring", stripe_recurring)
  let price_type =
    field(
      "price_type",
      string_enum([
        #("one_time", types.OneTime),
        #("recurring", types.Recurring),
      ]),
    )
  let unit_amount = nullable_field("unit_amount", int)
  let created = field("created", stripe_timestamp)
  let livemode = field("livemode", bool)
  let billing_scheme =
    field(
      "billing_scheme",
      string_enum([#("per_unit", types.PerUnit), #("tiered", types.Tiered)]),
    )

  use id <- try(id(obj))
  use active <- try(active(obj))
  use currency <- try(currency(obj))
  use metadata <- try(metadata(obj))
  use nickname <- try(nickname(obj))
  use product <- try(product(obj))
  use recurring <- try(recurring(obj))
  use price_type <- try(price_type(obj))
  use unit_amount <- try(unit_amount(obj))
  use created <- try(created(obj))
  use livemode <- try(livemode(obj))
  use billing_scheme <- try(billing_scheme(obj))
  Ok(types.Price(
    id: id,
    json: obj,
    active: active,
    currency: currency,
    metadata: metadata,
    nickname: nickname,
    product: product,
    recurring: recurring,
    price_type: price_type,
    unit_amount: unit_amount,
    created: created,
    livemode: livemode,
    billing_scheme: billing_scheme,
  ))
}

pub fn stripe_data(json obj: Dynamic) -> Result(StripeData, DecodeErrors) {
  dynamic.any([stripe_event, stripe_customer, stripe_product, stripe_price])(
    obj,
  )
}
