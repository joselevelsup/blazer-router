import blazer
import gleam/dict
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/option
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

fn req(method: http.Method, path: String) -> request.Request(String) {
  request.new()
  |> request.set_method(method)
  |> request.set_path(path)
}

pub fn static_route_test() {
  let r =
    blazer.new()
    |> blazer.get("/users", fn(_, _, _) {
      response.new(200) |> response.set_body("users")
    })

  let resp =
    blazer.consume(r, req(http.Get, "/users"), fn(_, _, _) { response.new(404) })

  assert resp.status == 200
    as "[static_route_test] Failed to get 200 from router"
  assert resp.body == "users"
    as "[static_route_test] Failed to get 'users' from router"
}

pub fn param_route_test() {
  let r =
    blazer.new()
    |> blazer.get("/users/:id", fn(_, _, params) {
      let assert option.Some(d) = params
      let assert Ok(id) = dict.get(d, "id")
      response.new(200) |> response.set_body(id)
    })

  let resp =
    blazer.consume(r, req(http.Get, "/users/42"), fn(_, _, _) {
      response.new(404)
    })

  assert resp.status == 200
    as "[param_route_test] Failed to get 200 from router"
  assert resp.body == "42"
    as "[param_route_test] Failed to get '42' in body from router"
}

pub fn nested_param_test() {
  let r =
    blazer.new()
    |> blazer.get("/users/:id/posts/:pid", fn(_, _, params) {
      let assert option.Some(d) = params
      let assert Ok(id) = dict.get(d, "id")
      let assert Ok(pid) = dict.get(d, "pid")
      response.new(200) |> response.set_body(id <> ":" <> pid)
    })

  let resp =
    blazer.consume(r, req(http.Get, "/users/7/posts/9"), fn(_, _, _) {
      response.new(404)
    })
  assert resp.body == "7:9"
    as "[nested_param_test] Failed to get nested params in body"
}

pub fn method_dispatch_test() {
  let r =
    blazer.new()
    |> blazer.get("/x", fn(_, _, _) {
      response.new(200) |> response.set_body("get")
    })
    |> blazer.post("/x", fn(_, _, _) {
      response.new(200) |> response.set_body("post")
    })

  assert blazer.consume(r, req(http.Get, "/x"), fn(_, _, _) {
      response.new(404)
    }).body
    == "get"
    as "[method_dispatch_test] Failed to match the method to 'get'"
  assert blazer.consume(r, req(http.Post, "/x"), fn(_, _, _) {
      response.new(404)
    }).body
    == "post"
    as "[method_dispatch_test] Failed to match the method to 'post'"
}

type TestContext {
  TestContext(user: option.Option(Int))
}

type SuccessResponse(a) {
  SuccessResponse(success: Bool, data: a)
}

pub fn with_context_test() {
  let ctx = TestContext(user: option.Some(1))
  let r =
    blazer.new_with_context(ctx)
    |> blazer.get("/users", fn(_, ctx, _) {
      case ctx.user {
        option.None ->
          response.new(400)
          |> response.set_header("Content-Type", "application/json")
          |> response.set_body(
            json.object([#("success", json.bool(False)), #("user", json.int(0))])
            |> json.to_string,
          )
        option.Some(user) ->
          response.new(200)
          |> response.set_header("Content-Type", "application/json")
          |> response.set_body(
            json.object([
              #("success", json.bool(True)),
              #("user", json.int(user)),
            ])
            |> json.to_string,
          )
      }
    })

  let resp =
    blazer.consume(r, req(http.Get, "/users"), fn(_, _, _) { response.new(404) })

  let assert Ok(parsed) =
    json.parse(resp.body, using: {
      use success <- decode.field("success", decode.bool)
      use user <- decode.field("user", decode.int)

      decode.success(SuccessResponse(success:, data: user))
    })
    as "[with_context_test] Failed to parse sample user context body response"

  assert parsed.success == True
    as "[with_context_test] Failed to get a successful response"
  assert parsed.data == 1
    as "[with_context_test] Failed to get the user id from context"
}
