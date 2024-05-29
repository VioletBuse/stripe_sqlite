import storch

const create_link_queue = storch.Migration(
  00_001,
  "
    create table stripe_link_queue
",
)
