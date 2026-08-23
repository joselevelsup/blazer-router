import fist
import gleam/bytes_tree
import gleam/dict
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/result
import mist

fn ok_json(body: String) -> response.Response(mist.ResponseData) {
  response.new(200)
  |> response.set_body(body |> bytes_tree.from_string |> mist.Bytes)
  |> response.set_header("Content-Type", "application/json")
}

fn j(msg: String) -> response.Response(mist.ResponseData) {
  ok_json(
    json.object([#("ok", json.bool(True)), #("msg", json.string(msg))])
    |> json.to_string,
  )
}

fn param_int(params: dict.Dict(String, String), key: String) -> Int {
  dict.get(params, key)
  |> result.unwrap(or: "")
  |> int.parse
  |> result.unwrap(or: 0)
}

pub fn main() -> Nil {
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))

  let router =
    fist.new()
    |> fist.get("/", to: fn(_req, _ctx, _params) {
      response.new(200)
      |> response.set_body(
        "<b>It works!</b>" |> bytes_tree.from_string |> mist.Bytes,
      )
      |> response.set_header("Content-Type", "text/html")
    })
    |> fist.get("/users/:id", to: fn(_req, _ctx, params) {
      let user_id = param_int(params, "id")
      response.new(200)
      |> response.set_body(
        json.object([
          #("success", json.bool(True)),
          #("user", json.int(user_id)),
        ])
        |> json.to_string
        |> bytes_tree.from_string
        |> mist.Bytes,
      )
      |> response.set_header("Content-Type", "application/json")
    })
    |> fist.get("/users/:userId/posts/:postId", to: fn(_req, _ctx, params) {
      let user_id = param_int(params, "userId")
      let post_id = param_int(params, "postId")
      response.new(200)
      |> response.set_body(
        json.object([
          #("success", json.bool(True)),
          #("user", json.int(user_id)),
          #("post", json.int(post_id)),
        ])
        |> json.to_string
        |> bytes_tree.from_string
        |> mist.Bytes,
      )
    })
    |> fist.get("/health", to: fn(_, _, _) { j("health") })
    |> fist.get("/status", to: fn(_, _, _) { j("status") })
    |> fist.get("/ping", to: fn(_, _, _) { j("pong") })
    |> fist.get("/about", to: fn(_, _, _) { j("about") })
    |> fist.get("/contact", to: fn(_, _, _) { j("contact") })
    |> fist.get("/feed", to: fn(_, _, _) { j("feed") })
    |> fist.get("/search", to: fn(_, _, _) { j("search") })
    |> fist.get("/profile", to: fn(_, _, _) { j("profile") })
    |> fist.get("/settings", to: fn(_, _, _) { j("settings") })
    |> fist.get("/cart", to: fn(_, _, _) { j("cart") })
    |> fist.get("/checkout", to: fn(_, _, _) { j("checkout") })
    |> fist.get("/login", to: fn(_, _, _) { j("login") })
    |> fist.get("/logout", to: fn(_, _, _) { j("logout") })
    |> fist.get("/register", to: fn(_, _, _) { j("register") })
    |> fist.get("/notifications", to: fn(_, _, _) { j("notifications") })
    |> fist.get("/api/v1/health", to: fn(_, _, _) { j("v1/health") })
    |> fist.get("/api/v1/status", to: fn(_, _, _) { j("v1/status") })
    |> fist.get("/api/v1/metrics", to: fn(_, _, _) { j("v1/metrics") })
    |> fist.get("/products", to: fn(_, _, _) { j("products") })
    |> fist.get("/orders", to: fn(_, _, _) { j("orders") })
    |> fist.get("/products/:id", to: fn(_, _, params) {
      let id = dict.get(params, "id") |> result.unwrap(or: "")
      j("product " <> id)
    })
    |> fist.get("/orders/:id", to: fn(_, _, params) {
      let id = dict.get(params, "id") |> result.unwrap(or: "")
      j("order " <> id)
    })
    |> fist.get("/orders/:id/items", to: fn(_, _, params) {
      let id = dict.get(params, "id") |> result.unwrap(or: "")
      j("order " <> id <> " items")
    })
    |> fist.get("/users/:id/followers", to: fn(_, _, params) {
      let id = dict.get(params, "id") |> result.unwrap(or: "")
      j("user " <> id <> " followers")
    })

  let assert Ok(_) =
    fn(req: request.Request(mist.Connection)) -> response.Response(
      mist.ResponseData,
    ) {
      fist.handle(router, req, Nil, fn() { not_found })
    }
    |> mist.new
    |> mist.bind("localhost")
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
