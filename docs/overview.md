# blazer

A tiny path-param router for Gleam. You register handlers on path patterns
like `/users/:id`, hand it an incoming HTTP request, and it calls the right
handler — passing you the parsed path params.

It works with any HTTP server that gives you a `gleam/http/request.Request`
and expects a response back. See [`with_mist.md`](./with_mist.md) and
[`with_smol.md`](./with_smol.md) for complete examples.

## Registering routes

```gleam
blazer.new()
|> blazer.get("/users",       fn(_req, _ctx, _params) { /* … */ })
|> blazer.post("/users",      fn(_req, _ctx, _params) { /* … */ })
|> blazer.get("/users/:id",   fn(_req, _ctx, params)  { /* … */ })
```

`get` / `post` / `put` / `delete` / `patch` are thin wrappers over `add`,
which takes an explicit `http.Method`. Each call returns a *new* router —
nothing is mutated — so pipe them in any order.

## Serving a request

```gleam
blazer.consume(router, request, not_found_handler)
```

`consume` walks the tree using the request's method + path. On a match it
calls the handler with `(request, context, params)` and returns whatever the
handler returns. On no match it calls your `not_found_handler`. blazer doesn't decide what a 404 looks like, you do.

## What blazer does not do

It is only the router. It doesn't start a server, parse query strings, or
handle middleware. You bring the server (mist, smol, …) and call `consume`
from its request handler. The examples show exactly how.
