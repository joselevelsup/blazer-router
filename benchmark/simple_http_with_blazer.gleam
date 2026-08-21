import blazer
import gleam/bytes_tree
import gleam/dict
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/result
import mist

pub fn main() -> Nil {
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))

  let router =
    blazer.new()
    |> blazer.get("/", fn(_req, _ctx, _params) {
      response.new(200)
      |> response.set_body(
        "<b>It works!</b>" |> bytes_tree.from_string |> mist.Bytes,
      )
      |> response.set_header("Content-Type", "text/html")
    })
    |> blazer.get("/users/:id", fn(_, _, params) {
      let user_id =
        dict.get(params, "id")
        |> result.unwrap(or: "")
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
    })
    |> blazer.get("/users/:userId/posts/:postId", fn(_, _, params) {
      let user_id =
        dict.get(params, "userId")
        |> result.unwrap(or: "")
        |> int.parse
        |> result.unwrap(or: 0)
      let post_id =
        dict.get(params, "postId")
        |> result.unwrap(or: "")
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
    })

  let assert Ok(_) =
    fn(req: request.Request(mist.Connection)) -> response.Response(
      mist.ResponseData,
    ) {
      blazer.consume(router, req, fn(_, _, _) { not_found })
    }
    |> mist.new
    |> mist.bind("localhost")
    |> mist.port(8081)
    |> mist.start

  process.sleep_forever()
}
