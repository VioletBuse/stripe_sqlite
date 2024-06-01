import gleam/dynamic.{type Dynamic}
import stripe/utils

pub opaque type PaymentMethod {
  PaymentMethod(id: String, json: Dynamic)
}

pub fn decode(dyn: Dynamic) {
  utils.stripe_object(PaymentMethod, "payment_method")(dyn)
}
