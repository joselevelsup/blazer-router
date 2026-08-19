import blazer
import smol

pub fn main() {
  let router =
    blazer.new()
    |> blazer.get("/", fn(_req, _ctx, _params) {
      smol.send_html("<b>It works!</b>")
    })

  let handler = fn(request) {
    blazer.consume(router, request, fn(_, _, _) {
      smol.send_string("Not Found")
    })
  }

  smol.new(handler)
  |> smol.start()
}
