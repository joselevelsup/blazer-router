# Using blazer with smol

[smol](https://hex.pm/packages/smol) is a small, simple HTTP server for
Gleam. This example is the shortest way to get blazer serving traffic.

If you aren't interested in the step by step, just look at the complete gleam files with the same name.

### 0. Install the packages

Create a Gleam project and add the packages this example uses:

```sh
gleam new my_app && cd my_app
gleam add blazer smol gleam_javascript
```

That's blazer (the router) and smol (the server).

### 1. Import the libraries

First start by importing the following libraries to make the example work:

```gleam
import blazer
import smol
```

Just blazer for routing and smol for the server.

### 2. Build the router

```gleam
pub fn main() {
  let router =
    blazer.new()
    |> blazer.get("/", fn(_req, _ctx, _params) {
      smol.send_html("<b>It works!</b>")
    })
```

`blazer.new()` creates a router with `Nil` context. We register one
`GET /` handler that ignores its arguments (`_req`, `_ctx`, `_params`) and
returns `smol.send_html(...)`. smol provides this helper to build a 200
response with an HTML body — that return value is the `res` in blazer's
`fn(req, ctx, params) -> res`.

### 3. Turn the router into a smol handler

```gleam
  let handler = fn(request) {
    blazer.consume(router, request, fn(_, _, _) {
      smol.send_string("Not Found")
    })
  }
```

smol calls our function with the incoming request. We hand it to
`blazer.consume`:

- **`router`** — the tree we built.
- **`request`** — the incoming request, passed straight through.
- **`fn(_, _, _) { smol.send_string("Not Found") }`** — the not-found handler
  blazer calls if no route matched. It ignores blazer's `(req, ctx, params)`
  args and returns a plain-text "Not Found" response via smol's helper.

`consume` returns whatever the matched handler returns, so our function
returns a smol response — exactly what smol expects back.

### 4. Start the server

```gleam
  smol.new(handler)
  |> smol.start()
}
```

We wrap our function in a smol server and start it. Unlike mist, smol's
`start` blocks, so there's no need to keep the program alive afterwards.

## How a request flows through it

1. smol receives `GET /`, calls `handler` with the request.
2. `handler` calls `blazer.consume(router, request, not_found_handler)`.
3. blazer tries to find the right route that matches the request. 
4. blazer calls `handler(req, ctx, params)` → returns the HTML response.
5. smol sends the response to the client.

For `GET /nope`, step 2 finds no match, so `consume` calls the not-found handler → the "Not Found" response.
