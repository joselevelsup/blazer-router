import blazer
import gleam/dict
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/option
import gleeunit
import gleeunit/should

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

  let resp = blazer.consume(r, req(http.Get, "/users"))
  should.equal(resp.status, 200)
  should.equal(resp.body, "users")
}

pub fn param_route_test() {
  let r =
    blazer.new()
    |> blazer.get("/users/:id", fn(_, _, params) {
      let assert option.Some(d) = params
      let assert Ok(id) = dict.get(d, "id")
      response.new(200) |> response.set_body(id)
    })

  let resp = blazer.consume(r, req(http.Get, "/users/42"))
  should.equal(resp.body, "42")
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

  let resp = blazer.consume(r, req(http.Get, "/users/7/posts/9"))
  should.equal(resp.body, "7:9")
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

  should.equal(blazer.consume(r, req(http.Get, "/x")).body, "get")
  should.equal(blazer.consume(r, req(http.Post, "/x")).body, "post")
}

pub fn miss_test() {
  let r =
    blazer.new() |> blazer.get("/users", fn(_, _, _) { response.new(200) })
  should.equal(blazer.match(r, http.Get, "/nope"), option.None)
  should.equal(blazer.match(r, http.Post, "/users"), option.None)
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

  let resp = blazer.consume(r, req(http.Get, "/users"))

  let assert Ok(parsed) =
    json.parse(resp.body, using: {
      use success <- decode.field("success", decode.bool)
      use user <- decode.field("user", decode.int)

      decode.success(SuccessResponse(success:, data: user))
    })
    as "Failed to parse sample user context body response"

  assert parsed.success == True
  assert parsed.data == 1
}
