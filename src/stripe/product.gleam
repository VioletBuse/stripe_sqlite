import gleam/dynamic.{type Dynamic}
import stripe/utils

pub opaque type Product {
  Product(id: String, json: Dynamic)
}

pub fn decode(dyn: Dynamic) {
  utils.stripe_object(Product, "product")(dyn)
}
