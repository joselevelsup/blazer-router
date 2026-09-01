import blazer
import client
import gleam/string
import simplifile

fn sample_router() {
  blazer.new()
  |> blazer.get("/users", fn(_, _, _) { Nil })
  |> blazer.get("/users/:id/posts/:pid", fn(_, _, _) { Nil })
  |> blazer.post("/users", fn(_, _, _) { Nil })
}

pub fn generate_test() {
  let assert Ok(_) = client.generate(sample_router(), "test/sample_client")
    as "Failed to generate client code"

  let assert Ok(gleam_client_code) =
    simplifile.read(from: "./test/sample_client.gleam")
    as "Could not read from file for client code"

  assert string.contains(
    gleam_client_code,
    "pub fn get_users(base: String) -> request.Request(String)",
  )
    as "missing get_users function"

  assert string.contains(
    gleam_client_code,
    "pub fn get_users_id_posts_pid(base: String, id: String, pid: String)",
  )
    as "param routes should become function arguments"

  assert string.contains(
    gleam_client_code,
    "request.set_path(base <> \"/users/\" <> id <> \"/posts/\" <> pid)",
  )
    as "param path expression is wrong"

  assert string.contains(gleam_client_code, "http.Post") as "post route missing"
}

pub fn write_error_test() {
  let assert Error(message) =
    client.generate(sample_router(), "test/no_such_dir/sample_client")
  assert string.contains(message, "Could not write client code")
  Nil
}
