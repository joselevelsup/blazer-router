import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
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
        _, _ -> not_found
      }
    }
    |> mist.new
    |> mist.bind("localhost")
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}
