import gleam/bool
import gleam/dynamic.{type DecodeErrors, type Dynamic, DecodeError}
import gleam/option.{type Option}
import gleam/result

pub fn stripe_object(
  constructor: fn(String, Dynamic) -> a,
  object_type: String,
) -> fn(Dynamic) -> Result(a, DecodeErrors) {
  fn(dyn: Dynamic) -> Result(a, DecodeErrors) {
    use _ <- result.try(dynamic.field("object", string_literal(object_type))(
      dyn,
    ))

    use id <- result.try(dynamic.field("id", dynamic.string)(dyn))
    Ok(constructor(id, dyn))
  }
}

pub fn string_literal(
  expected value: String,
) -> fn(Dynamic) -> Result(Nil, DecodeErrors) {
  fn(dyn: Dynamic) -> Result(Nil, DecodeErrors) {
    use str_value <- result.try(dynamic.string(dyn))
    use <- bool.guard(when: str_value == value, return: Ok(Nil))

    Error([DecodeError(expected: value, found: str_value, path: [])])
  }
}

pub fn nullable_field(
  named name: a,
  of inner_type: fn(Dynamic) -> Result(b, DecodeErrors),
) -> fn(Dynamic) -> Result(Option(b), DecodeErrors) {
  fn(dyn: Dynamic) -> Result(Option(b), DecodeErrors) {
    let decode_res =
      dynamic.optional_field(name, dynamic.optional(inner_type))(dyn)
    use opt <- result.map(decode_res)
    option.flatten(opt)
  }
}

pub fn get_field(
  named name: String,
  of inner_type: fn(Dynamic) -> Result(b, DecodeErrors),
  from dyn: Dynamic,
) -> Result(b, Nil) {
  let decoder = dynamic.optional_field(name, dynamic.optional(inner_type))
  let value = decoder(dyn)

  result.nil_error(value)
  |> result.map(option.flatten)
  |> result.map(option.to_result(_, Nil))
  |> result.flatten
}

pub fn get_required_field(
  named name: String,
  of inner_type: fn(Dynamic) -> Result(b, DecodeErrors),
  from dyn: Dynamic,
) -> b {
  let decoder = dynamic.field(name, inner_type)
  let value = decoder(dyn)

  case value {
    Ok(inner) -> inner
    Error(_) -> {
      let panic_error = "unable to get required_field " <> name
      panic as panic_error
    }
  }
}
