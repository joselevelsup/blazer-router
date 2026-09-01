import blazer
import client
import gleam/string

fn sample_router() {
  blazer.new()
  |> blazer.get("/users", fn(_, _, _) { Nil })
  |> blazer.get("/users/:id/posts/:pid", fn(_, _, _) { Nil })
  |> blazer.post("/users", fn(_, _, _) { Nil })
}

pub fn generate_test() {
  let src = client.generate(sample_router())

  assert string.contains(
    src,
    "pub fn get_users(base: String) -> request.Request(String)",
  )
  as "missing get_users function"

  assert string.contains(
    src,
    "pub fn get_users_id_posts_pid(base: String, id: String, pid: String)",
  )
  as "param routes should become function arguments"

  assert string.contains(
    src,
    "request.set_path(base <> \"/users/\" <> id <> \"/posts/\" <> pid)",
  )
  as "param path expression is wrong"

  assert string.contains(src, "http.Post")
  as "post route missing"
}
