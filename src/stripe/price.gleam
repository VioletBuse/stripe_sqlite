import gleam/dynamic.{type Dynamic}
import stripe/utils

pub opaque type Price {
  Price(id: String, json: Dynamic)
}

pub fn decode(dyn: Dynamic) {
  utils.stripe_object(Price, "price")(dyn)
}
