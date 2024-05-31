import gleam/dynamic.{type DecodeErrors, type Dynamic}
import gleam/option.{type Option}
import gleam/result
import stripe/utils

pub type CustomerAddress {
  CustomerAddress(
    city: Option(String),
    country: Option(String),
    line1: Option(String),
    line2: Option(String),
    postal_code: Option(String),
    state: Option(String),
  )
}

pub type CustomerShipping {
  CustomerShipping(
    address: CustomerAddress,
    name: String,
    phone: Option(String),
  )
}

pub type Customer {
  Customer(id: String, json: Dynamic)
}

pub fn decode_customer(dyn: Dynamic) -> Result(Customer, DecodeErrors) {
  use _ <- result.try(dynamic.field("object", utils.string_literal("customer"))(
    dyn,
  ))
  use id <- result.try(dynamic.field("id", dynamic.string)(dyn))

  Ok(Customer(id, dyn))
}

fn decode_address(dyn: Dynamic) {
  let decoder =
    dynamic.decode6(
      CustomerAddress,
      utils.nullable_field("city", dynamic.string),
      utils.nullable_field("country", dynamic.string),
      utils.nullable_field("line1", dynamic.string),
      utils.nullable_field("line2", dynamic.string),
      utils.nullable_field("postal_code", dynamic.string),
      utils.nullable_field("state", dynamic.string),
    )

  decoder(dyn)
}

pub fn address(customer: Customer) -> Result(CustomerAddress, Nil) {
  utils.get_field("address", decode_address, customer.json)
}

pub fn description(customer: Customer) {
  utils.get_field("description", dynamic.string, customer.json)
}

pub fn email(customer: Customer) {
  utils.get_field("email", dynamic.string, customer.json)
}

pub fn metadata(customer: Customer) {
  utils.get_required_field("metadata", dynamic.dynamic, customer.json)
}

pub fn name(customer: Customer) {
  utils.get_field("name", dynamic.string, customer.json)
}

pub fn phone(customer: Customer) {
  utils.get_field("phone", dynamic.string, customer.json)
}

fn decode_shipping(dyn: Dynamic) {
  let decoder =
    dynamic.decode3(
      CustomerShipping,
      dynamic.field("address", decode_address),
      dynamic.field("name", dynamic.string),
      utils.nullable_field("phone", dynamic.string),
    )

  decoder(dyn)
}

pub fn shipping(customer: Customer) {
  utils.get_field("shipping", decode_shipping, customer.json)
}

pub fn balance(customer: Customer) {
  utils.get_required_field("balance", dynamic.int, customer.json)
}

pub fn created(customer: Customer) {
  utils.get_required_field("created", dynamic.int, customer.json)
}

pub fn delinquent(customer: Customer) {
  utils.get_field("delinquent", dynamic.bool, customer.json)
}
