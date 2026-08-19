# Blazer Router

A "blazingly easy" path-param router for Gleam.

> Blazer at the time of writing this documentation HAS NOT BEEN PUBLISHED

```sh
gleam add blazer@1
```

```gleam
import blazer

pub fn main() {
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
    
  //This handler is what generally gets passed into whatever server framework you are working with
  let handler = fn(req) {
    blazer.consume(router, request, not_found_handler)
  }
    
    
  //Start your server
}

```

Routes are registered with `get` / `post` / `put` / `delete` / `patch` and support `:param` segments, which are captured and passed to your handler as a dict. blazer is router-only — pair it with any HTTP server that speaks `gleam/http` (mist, smol, …) and have it call `consume` per request.

See [Overview](./docs/overview.md) for the core concepts, and [With Mist](./docs/with_mist.md) / [With Smol](./docs/with_smol.md)
for complete runnable examples.

## Roadmap
- [x] Basic Routing
- [x] Implemented with 2 different types of servers
- [x] Parameters are included
- [] Middleware?

This roadmap might get updated with anything else I might want to include. Anything marked with a "?" is being determined if I want to include it or not.

## Inspiration/Credit
- [Fist Router](https://fist.hexdocs.pm/) (@MrTomatePNG)
  - I really enjoyed working with this router and it made everything simpler to use. Most of the API was based off of this project. Unfortunately the github is no longer available but regardless THANK YOU!
  
## Questions/Feedback
If you have any questions, feedback, or running into issues, feel free to open an issue and I will try to reach out when I can!

### AI Usage
AI was used to create most of the documentation and helped with planning out how to tackle this project. Minimal agent code was used in the codebase. I have written 95% of the code. Do with this information what you will.
