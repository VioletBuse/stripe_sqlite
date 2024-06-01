import gleam/dynamic.{type Dynamic}
import stripe/utils

pub opaque type Card {
  Card(id: String, json: Dynamic)
}

pub fn decode(dyn: Dynamic) {
  utils.stripe_object(Card, "card")(dyn)
}
