import gleam/dynamic.{type Dynamic}
import gleam/result
import stripe/utils

pub opaque type EventType {
  CustomerCreated
  CustomerUpdated
  CustomerDeleted
  PriceCreated
  PriceUpdated
  PriceDeleted
  ProductCreated
  ProductUpdated
  ProductDeleted
}

pub opaque type Event {
  Event(id: String, json: Dynamic)
}

pub fn decode(dyn: Dynamic) {
  utils.stripe_object(Event, "event")(dyn)
}

pub fn account(event: Event) {
  utils.get_field("account", dynamic.string, event.json)
}

pub fn created(event: Event) {
  utils.get_required_field("created", dynamic.int, event.json)
}

pub fn livemode(event: Event) {
  utils.get_required_field("livemode", dynamic.bool, event.json)
}

pub fn event_object_dynamic(event: Event) {
  utils.get_required_field(
    "data",
    dynamic.field("object", dynamic.dynamic),
    event.json,
  )
}

pub fn event_data(
  event: Event,
  decoder decoder: fn(Dynamic) -> Result(a, dynamic.DecodeErrors),
) -> Result(a, Nil) {
  utils.get_required_field(
    "data",
    dynamic.field("object", dynamic.dynamic),
    event.json,
  )
  |> decoder
  |> result.nil_error
}

pub fn event_type(event: Event) -> Result(EventType, Nil) {
  use evt_type <- result.try(utils.get_field("type", dynamic.string, event.json))

  case evt_type {
    "customer.created" -> Ok(CustomerCreated)
    "customer.updated" -> Ok(CustomerUpdated)
    "customer.deleted" -> Ok(CustomerDeleted)
    "price.created" -> Ok(PriceCreated)
    "price.updated" -> Ok(PriceUpdated)
    "price.deleted" -> Ok(PriceDeleted)
    "product.created" -> Ok(ProductCreated)
    "product.updated" -> Ok(ProductUpdated)
    "product.deleted" -> Ok(ProductDeleted)
    _ -> Error(Nil)
  }
}
