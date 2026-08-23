import blazer
import gleam/bytes_tree
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

pub fn main() -> Nil {
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))

  let router =
    blazer.new()
    |> blazer.get(
      "/",
      blazer.handler(fn(_req, _ctx) {
        response.new(200)
        |> response.set_body(
          "<b>It works!</b>" |> bytes_tree.from_string |> mist.Bytes,
        )
        |> response.set_header("Content-Type", "text/html")
      }),
    )
    |> blazer.get(
      "/users/:id",
      blazer.handler_with_params(fn(_, _, params) {
        let user_id =
          blazer.get_param(params, "id")
          |> int.parse
          |> result.unwrap(or: 0)
        response.new(200)
        |> response.set_body({
          json.object([
            #("success", json.bool(True)),
            #("user", json.int(user_id)),
          ])
          |> json.to_string
          |> bytes_tree.from_string
          |> mist.Bytes
        })
        |> response.set_header("Content-Type", "application/json")
      }),
    )
    |> blazer.get(
      "/users/:userId/posts/:postId",
      blazer.handler_with_params(fn(_, _, params) {
        let user_id =
          blazer.get_param(params, "userId")
          |> int.parse
          |> result.unwrap(or: 0)
        let post_id =
          blazer.get_param(params, "postId")
          |> int.parse
          |> result.unwrap(or: 0)

        response.new(200)
        |> response.set_body({
          json.object([
            #("success", json.bool(True)),
            #("user", json.int(user_id)),
            #("post", json.int(post_id)),
          ])
          |> json.to_string
          |> bytes_tree.from_string
          |> mist.Bytes
        })
      }),
    )
    |> blazer.get("/health", blazer.handler(fn(_, _) { j("health") }))
    |> blazer.get("/status", blazer.handler(fn(_, _) { j("status") }))
    |> blazer.get("/ping", blazer.handler(fn(_, _) { j("pong") }))
    |> blazer.get("/about", blazer.handler(fn(_, _) { j("about") }))
    |> blazer.get("/contact", blazer.handler(fn(_, _) { j("contact") }))
    |> blazer.get("/feed", blazer.handler(fn(_, _) { j("feed") }))
    |> blazer.get("/search", blazer.handler(fn(_, _) { j("search") }))
    |> blazer.get("/profile", blazer.handler(fn(_, _) { j("profile") }))
    |> blazer.get("/settings", blazer.handler(fn(_, _) { j("settings") }))
    |> blazer.get("/cart", blazer.handler(fn(_, _) { j("cart") }))
    |> blazer.get("/checkout", blazer.handler(fn(_, _) { j("checkout") }))
    |> blazer.get("/login", blazer.handler(fn(_, _) { j("login") }))
    |> blazer.get("/logout", blazer.handler(fn(_, _) { j("logout") }))
    |> blazer.get("/register", blazer.handler(fn(_, _) { j("register") }))
    |> blazer.get(
      "/notifications",
      blazer.handler(fn(_, _) { j("notifications") }),
    )
    |> blazer.get("/api/v1/health", blazer.handler(fn(_, _) { j("v1/health") }))
    |> blazer.get("/api/v1/status", blazer.handler(fn(_, _) { j("v1/status") }))
    |> blazer.get(
      "/api/v1/metrics",
      blazer.handler(fn(_, _) { j("v1/metrics") }),
    )
    |> blazer.get("/products", blazer.handler(fn(_, _) { j("products") }))
    |> blazer.get("/orders", blazer.handler(fn(_, _) { j("orders") }))
    |> blazer.get(
      "/products/:id",
      blazer.handler_with_params(fn(_, _, params) {
        let id = blazer.get_param(params, "id")
        j("product " <> id)
      }),
    )
    |> blazer.get(
      "/orders/:id",
      blazer.handler_with_params(fn(_, _, params) {
        let id = blazer.get_param(params, "id")
        j("order " <> id)
      }),
    )
    |> blazer.get(
      "/orders/:id/items",
      blazer.handler_with_params(fn(_, _, params) {
        let id = blazer.get_param(params, "id")
        j("order " <> id <> " items")
      }),
    )
    |> blazer.get(
      "/users/:id/followers",
      blazer.handler_with_params(fn(_, _, params) {
        let id = blazer.get_param(params, "id")
        j("user " <> id <> " followers")
      }),
    )

  let assert Ok(_) =
    fn(req: request.Request(mist.Connection)) -> response.Response(
      mist.ResponseData,
    ) {
      blazer.consume(router, req, blazer.handler(fn(_, _) { not_found }))
    }
    |> mist.new
    |> mist.bind("localhost")
    |> mist.port(8081)
    |> mist.start

  process.sleep_forever()
}
