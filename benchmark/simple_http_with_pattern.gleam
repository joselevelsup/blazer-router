import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
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

  let assert Ok(_) =
    fn(req: request.Request(mist.Connection)) -> response.Response(
      mist.ResponseData,
    ) {
      case req.method, request.path_segments(req) {
        http.Get, [] -> {
          response.new(200)
          |> response.set_body(
            "<b>It works!</b>" |> bytes_tree.from_string |> mist.Bytes,
          )
          |> response.set_header("Content-Type", "text/html")
        }
        http.Get, ["users", id] -> {
          response.new(200)
          |> response.set_body({
            json.object([
              #("success", json.bool(True)),
              #("user", json.int(id |> int.parse |> result.unwrap(or: 0))),
            ])
            |> json.to_string
            |> bytes_tree.from_string
            |> mist.Bytes
          })
          |> response.set_header("Content-Type", "application/json")
        }
        http.Get, ["users", user_id, "posts", post_id] -> {
          response.new(200)
          |> response.set_body({
            json.object([
              #("success", json.bool(True)),
              #("user", json.int(user_id |> int.parse |> result.unwrap(or: 0))),
              #("post", json.int(post_id |> int.parse |> result.unwrap(or: 0))),
            ])
            |> json.to_string
            |> bytes_tree.from_string
            |> mist.Bytes
          })
          |> response.set_header("Content-Type", "application/json")
        }
        http.Get, ["health"] -> j("health")
        http.Get, ["status"] -> j("status")
        http.Get, ["ping"] -> j("pong")
        http.Get, ["about"] -> j("about")
        http.Get, ["contact"] -> j("contact")
        http.Get, ["feed"] -> j("feed")
        http.Get, ["search"] -> j("search")
        http.Get, ["profile"] -> j("profile")
        http.Get, ["settings"] -> j("settings")
        http.Get, ["cart"] -> j("cart")
        http.Get, ["checkout"] -> j("checkout")
        http.Get, ["login"] -> j("login")
        http.Get, ["logout"] -> j("logout")
        http.Get, ["register"] -> j("register")
        http.Get, ["notifications"] -> j("notifications")
        http.Get, ["api", "v1", "health"] -> j("v1/health")
        http.Get, ["api", "v1", "status"] -> j("v1/status")
        http.Get, ["api", "v1", "metrics"] -> j("v1/metrics")
        http.Get, ["products"] -> j("products")
        http.Get, ["orders"] -> j("orders")
        http.Get, ["products", id] -> j("product " <> id)
        http.Get, ["orders", id] -> j("order " <> id)
        http.Get, ["orders", id, "items"] -> j("order " <> id <> " items")
        http.Get, ["users", id, "followers"] -> j("user " <> id <> " followers")
        _, _ -> not_found
      }
    }
    |> mist.new
    |> mist.bind("localhost")
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
