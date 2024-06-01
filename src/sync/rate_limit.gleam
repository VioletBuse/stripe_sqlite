import cli
import gleam/erlang/process.{type Subject}
import gleam/otp/actor

pub type ExternalMessage {
  Shutdown
}

pub fn start(
  limit: Int,
  parent_subject: Subject(Subject(ExternalMessage)),
) -> Result(Subject(ExternalMessage), actor.StartError) {
  todo
}
