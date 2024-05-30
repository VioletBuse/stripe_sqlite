import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}

pub type StripeAddress {
  StripeAddress(
    json: Dynamic,
    city: Option(String),
    country: Option(String),
    line1: Option(String),
    line2: Option(String),
    postal_code: Option(String),
    state: Option(String),
  )
}

pub type StripeShipping {
  StripeShipping(
    json: Dynamic,
    address: StripeAddress,
    name: String,
    phone: Option(String),
  )
}

pub type StripeTimestamp {
  IntTimestamp(Int)
}

pub type StripeAggregateUsage {
  LastDuringPeriod
  LastEver
  Max
  Sum
}

pub type StripeInterval {
  Day
  Week
  Month
  Year
}

pub type StripeUsageType {
  Metered
  Licensed
}

pub type StripeRecurring {
  StripeRecurring(
    json: Dynamic,
    aggregate_usage: StripeAggregateUsage,
    interval: StripeInterval,
    interval_count: Int,
    meter: Option(String),
    usage_type: StripeUsageType,
  )
}

pub type PriceType {
  OneTime
  Recurring
}

pub type BillingScheme {
  PerUnit
  Tiered
}

pub type StripeData {
  Event(
    id: String,
    event_type: String,
    json: Dynamic,
    account: Option(String),
    api_version: String,
    created: StripeTimestamp,
    data: StripeData,
    livemode: Bool,
  )
  Customer(
    id: String,
    json: Dynamic,
    address: Option(StripeAddress),
    description: Option(String),
    email: Option(String),
    metadata: Dynamic,
    name: Option(String),
    phone: Option(String),
    shipping: Option(StripeShipping),
    created: StripeTimestamp,
    livemode: Bool,
    delinquent: Option(Bool),
    balance: Int,
    currency: Option(String),
  )
  Product(
    id: String,
    json: Dynamic,
    active: Bool,
    default_price: Option(String),
    description: Option(String),
    metadata: Dynamic,
    name: String,
    created: StripeTimestamp,
    images: List(String),
    livemode: Bool,
    updated: StripeTimestamp,
    url: Option(String),
  )
  Price(
    id: String,
    json: Dynamic,
    active: Bool,
    currency: String,
    metadata: Dynamic,
    nickname: Option(String),
    product: String,
    recurring: Option(StripeRecurring),
    price_type: PriceType,
    unit_amount: Option(Int),
    created: StripeTimestamp,
    livemode: Bool,
    billing_scheme: BillingScheme,
  )
}
