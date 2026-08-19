# Blazer Router

A simple, "blazingly easy" path-param router for Gleam.

> Blazer at the time of writing this documentation HAS NOT BEEN PUBLISHED

```sh
gleam add blazer@1
```

```gleam
import blazer
import gleam/http

let router =
  blazer.new()
  |> blazer.get("/users", fn(_req, _ctx, _params) {
    // list all users
  })
  |> blazer.get("/users/:id", fn(_req, _ctx, params) {
    // params holds the captured "id"
  })
  |> blazer.post("/users", fn(_req, _ctx, _params) {
    // create a user
  })

// hand `router` to your server and call `blazer.consume(router, request, not_found)`
// for each incoming request.
```

Routes are registered with `get` / `post` / `put` / `delete` / `patch` and
support `:param` segments, which are captured and passed to your handler as a
dict. blazer is router-only — pair it with any HTTP server that speaks
`gleam/http` (mist, smol, …) and have it call `consume` per request.

See [Overview](./docs/overview.md) for the core concepts, and
[With Mist](./docs/with_mist.md) / [With Smol](./docs/with_smol.md)
for complete runnable examples.

## Inspiration/Credit
- [Fist Router](https://fist.hexdocs.pm/) (@MrTomatePNG)
  - I really enjoyed working with this router and it made everything simpler to use. Most of the API was based off of this project. Unfortunately the github is no longer available but regardless THANK YOU!
  
## Questions/Feedback
If you have any questions, feedback, or running into issues, feel free to open an issue and I will try to reach out when I can!

### AI Usage
AI was used to create most of the documentation and helped with planning out how to tackle this project. Minimal agent code was used in the codebase. I have written 95% of the code. Do with this information what you will.
