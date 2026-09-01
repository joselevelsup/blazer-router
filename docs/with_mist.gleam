import blazer
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import mist

pub fn main() -> Nil {
  let not_found =
    response.new(404)
    |> response.set_body(mist.Bytes(bytes_tree.new()))

  let router =
    blazer.new()
    |> blazer.get("/", fn(_req, _ctx, _params) {
      response.new(200)
      |> response.set_body(
        "<b>It works!</b>" |> bytes_tree.from_string |> mist.Bytes,
      )
      |> response.set_header("Content-Type", "text/html")
    })

  let assert Ok(_) = blazer_client.generate(router)

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

  process.sleep_forever()
}
