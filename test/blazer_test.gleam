import blazer
import envoy
import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
import gleam/json
import gleam/list
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
    |> blazer.get(
      "/users",
      blazer.handler(fn(_, _) {
        response.new(200) |> response.set_body("users")
      }),
    )

  let resp =
    blazer.consume(
      r,
      req(http.Get, "/users"),
      blazer.handler(fn(_, _) { response.new(404) }),
    )

  assert resp.status == 200
    as "[static_route_test] Failed to get 200 from router"
  assert resp.body == "users"
    as "[static_route_test] Failed to get 'users' from router"
}

pub fn param_route_test() {
  let r =
    blazer.new()
    |> blazer.get(
      "/users/:id",
      blazer.handler_with_params(fn(_, _, params) {
        let assert Ok(id) = dict.get(params, "id")
        response.new(200) |> response.set_body(id)
      }),
    )

  let resp =
    blazer.consume(
      r,
      req(http.Get, "/users/42"),
      blazer.handler(fn(_, _) { response.new(404) }),
    )

  assert resp.status == 200
    as "[param_route_test] Failed to get 200 from router"
  assert resp.body == "42"
    as "[param_route_test] Failed to get '42' in body from router"
}

pub fn nested_param_test() {
  let r =
    blazer.new()
    |> blazer.get(
      "/users/:id/posts/:pid",
      blazer.handler_with_params(fn(_, _, params) {
        let assert Ok(id) = dict.get(params, "id")
        let assert Ok(pid) = dict.get(params, "pid")
        response.new(200) |> response.set_body(id <> ":" <> pid)
      }),
    )

  let resp =
    blazer.consume(
      r,
      req(http.Get, "/users/7/posts/9"),
      blazer.handler(fn(_, _) { response.new(404) }),
    )
  assert resp.body == "7:9"
    as "[nested_param_test] Failed to get nested params in body"
}

pub fn method_dispatch_test() {
  let r =
    blazer.new()
    |> blazer.get(
      "/x",
      blazer.handler(fn(_, _) { response.new(200) |> response.set_body("get") }),
    )
    |> blazer.post(
      "/x",
      blazer.handler(fn(_, _) { response.new(200) |> response.set_body("post") }),
    )

  assert blazer.consume(
      r,
      req(http.Get, "/x"),
      blazer.handler(fn(_, _) { response.new(404) }),
    ).body
    == "get"
    as "[method_dispatch_test] Failed to match the method to 'get'"
  assert blazer.consume(
      r,
      req(http.Post, "/x"),
      blazer.handler(fn(_, _) { response.new(404) }),
    ).body
    == "post"
    as "[method_dispatch_test] Failed to match the method to 'post'"
}

type TestContext {
  TestContext(user: option.Option(Int))
}

@external(erlang, "timer", "tc")
fn tc(f: fn() -> a) -> #(Int, a)

type SuccessResponse(a) {
  SuccessResponse(success: Bool, data: a)
}

fn loop_n(f: fn() -> _, n: Int) -> Nil {
  case n {
    0 -> Nil
    _ -> {
      let _ = f()
      loop_n(f, n - 1)
    }
  }
}

fn time_n(f: fn() -> _, n: Int) -> Int {
  let #(us, _) = tc(fn() { loop_n(f, n) })
  us
}

fn median(samples: List(Int)) -> Int {
  let sorted = list.sort(samples, by: int.compare)
  let n = list.length(sorted)
  let assert Ok(v) = list.drop(sorted, n / 2) |> list.first
  v
}

fn bench_run(name: String, f: fn() -> _, n: Int, samples: Int) -> Float {
  loop_n(f, n)
  let times =
    list.repeat(Nil, samples)
    |> list.map(fn(_) { time_n(f, n) })
  let per_call = int.to_float(median(times)) /. int.to_float(n)
  case envoy.get("BENCH") {
    Ok(_) ->
      io.println(
        "[bench] "
        <> name
        <> ": "
        <> float.to_string(per_call)
        <> " us/call (n="
        <> int.to_string(n)
        <> ", samples="
        <> int.to_string(samples)
        <> ")",
      )
    Error(_) -> Nil
  }
  per_call
}

pub fn bench_match_test() {
  let static_router =
    blazer.new()
    |> blazer.get("/users", blazer.handler(fn(_, _) { response.new(200) }))
  let param_router =
    blazer.new()
    |> blazer.get(
      "/users/:id",
      blazer.handler_with_params(fn(_, _, _) { response.new(200) }),
    )
  let nested_router =
    blazer.new()
    |> blazer.get(
      "/users/:id/posts/:pid",
      blazer.handler_with_params(fn(_, _, _) { response.new(200) }),
    )

  let static_us =
    bench_run(
      "static",
      fn() { blazer.match(static_router, http.Get, "/users") },
      10_000,
      7,
    )
  let param_us =
    bench_run(
      "param",
      fn() { blazer.match(param_router, http.Get, "/users/42") },
      10_000,
      7,
    )
  let nested_us =
    bench_run(
      "nested",
      fn() { blazer.match(nested_router, http.Get, "/users/7/posts/9") },
      10_000,
      7,
    )

  assert static_us <. 10.0 as "[bench] static match regressed beyond 10us/call"
  assert param_us <. 15.0 as "[bench] param match regressed beyond 15us/call"
  assert nested_us <. 20.0 as "[bench] nested match regressed beyond 20us/call"
}

pub fn with_context_test() {
  let ctx = TestContext(user: option.Some(1))
  let r =
    blazer.new_with_context(ctx)
    |> blazer.get(
      "/users",
      blazer.handler(fn(_, ctx: TestContext) {
        case ctx.user {
          option.None ->
            response.new(400)
            |> response.set_header("Content-Type", "application/json")
            |> response.set_body(
              json.object([
                #("success", json.bool(False)),
                #("user", json.int(0)),
              ])
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
      }),
    )

  let resp =
    blazer.consume(
      r,
      req(http.Get, "/users"),
      blazer.handler(fn(_, _) { response.new(404) }),
    )

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
