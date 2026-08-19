import gleeunit
import gleam/dict
import gleam/option
import gleeunit/should
import blazer

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn static_route_test() {
  let r =
    blazer.new(Nil)
    |> blazer.get("/users", fn(_, _, _) { "users" })

  let assert option.Some(#(handler, params)) =
    blazer.match(r, blazer.Get, "/users")
  should.equal(handler(Nil, Nil, option.None), "users")
  should.equal(params, option.None)
}

pub fn param_route_test() {
  let r =
    blazer.new(Nil)
    |> blazer.get("/users/:id", fn(_, _, _) { "user" })

  let assert option.Some(#(_, params)) =
    blazer.match(r, blazer.Get, "/users/42")
  let assert option.Some(d) = params
  should.equal(dict.get(d, "id"), Ok("42"))
}

pub fn nested_param_test() {
  let r =
    blazer.new(Nil)
    |> blazer.get("/users/:id/posts/:pid", fn(_, _, _) { "post" })

  let assert option.Some(#(_, params)) =
    blazer.match(r, blazer.Get, "/users/7/posts/9")
  let assert option.Some(d) = params
  should.equal(dict.get(d, "id"), Ok("7"))
  should.equal(dict.get(d, "pid"), Ok("9"))
}

pub fn method_dispatch_test() {
  let r =
    blazer.new(Nil)
    |> blazer.get("/x", fn(_, _, _) { "get" })
    |> blazer.post("/x", fn(_, _, _) { "post" })

  let assert option.Some(#(h_get, _)) =
    blazer.match(r, blazer.Get, "/x")
  let assert option.Some(#(h_post, _)) =
    blazer.match(r, blazer.Post, "/x")
  should.equal(h_get(Nil, Nil, option.None), "get")
  should.equal(h_post(Nil, Nil, option.None), "post")
}

pub fn miss_test() {
  let r = blazer.new(Nil) |> blazer.get("/users", fn(_, _, _) { "x" })
  should.equal(blazer.match(r, blazer.Get, "/nope"), option.None)
  should.equal(blazer.match(r, blazer.Post, "/users"), option.None)
}
