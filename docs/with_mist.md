# Using blazer with mist

[mist](https://hex.pm/packages/mist) is a high-performance HTTP server for
Gleam/Erlang. This is the most common way to run the blazer router.

If you aren't interested in the step by step, just look at the complete gleam files with the same name.

### 0. Install the packages

Create a Gleam project and add the packages this example uses:

```sh
gleam new my_app && cd my_app
gleam add blazer mist gleam_http
```

That's blazer (the router), mist (the server), and `gleam_http` (the shared
request/response types both blazer and mist speak).

### 1. Import the libraries

First start by importing the following libraries to make the example work

```gleam
import blazer
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import mist
```

### 2. Build a fallback response

```gleam
pub fn main() -> Nil {
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
```

mist's response body type is `mist.ResponseData`, which wraps a `bytes_tree`.
Here we make an empty-body 404 response once and reuse it for every
unmatched request.

### 3. Build the router

```gleam
  let router =
    blazer.new()
    |> blazer.get("/", fn(_req, _ctx, _params) {
      response.new(200)
      |> response.set_body(
        "<b>It works!</b>" |> bytes_tree.from_string |> mist.Bytes,
      )
      |> response.set_header("Content-Type", "text/html")
    })
```

`blazer.new()` creates a router with `Nil` context (we don't need shared
state here — see [`overview.md`](./overview.md) for `new_with_context`).

We register one `GET /` handler. The handler ignores its arguments
(`_req`, `_ctx`, `_params`) and returns a 200 response whose body is the HTML
string, converted to `bytes_tree` and wrapped in `mist.Bytes` so mist can
send it. This is the `res` in blazer's `fn(req, ctx, params) -> res` — here
`res` is `response.Response(mist.ResponseData)`.

### 4. Turn the router into a mist handler

```gleam
  let assert Ok(_) =
    fn(req: request.Request(mist.Connection)) -> response.Response(
      mist.ResponseData,
    ) {
      blazer.consume(router, req, fn(_, _, _) { not_found })
    }
    |> mist.new
    |> mist.bind("localhost")
    |> mist.port(4000)
    |> mist.start
```

This is the bridge between blazer and mist. mist calls our function with a
`request.Request(mist.Connection)` (the `req` body type is mist's socket
type). Inside, we hand the request to `blazer.consume`:

- **`router`** — the tree we built.
- **`req`** — the incoming request, passed straight through.
- **`fn(_, _, _) { not_found }`** — the not-found handler blazer calls if no
  route matched. It ignores blazer's `(req, ctx, params)` args and returns the
  404 response we made earlier.

`consume` returns whatever the matched handler returns, so our function
returns `response.Response(mist.ResponseData)` — exactly the shape mist
expects. We then configure the server (localhost:4000) and start it.

### 5. Keep the program alive

```gleam
  process.sleep_forever()
}
```

`mist.start` spawns the server in the background and returns immediately.
Without this line `main` would exit and take the server down with it.

## How a request flows through it

1. mist receives `GET /`, calls our function with the request.
2. Our function calls `blazer.consume(router, req, not_found_handler)`.
3. blazer tries to find the right route that matches the request. 
4. blazer calls the `handler(req, ctx, params)` which then returns the 200 HTML response.
5. mist sends it to the client.

For `GET /nope`, step 3 finds no match, so `consume` calls the not-found
handler → the 404 response.
