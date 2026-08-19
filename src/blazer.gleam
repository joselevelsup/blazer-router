import gleam/dict
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/option
import gleam/string

pub type Handler(req, res, ctx) =
  fn(request.Request(req), ctx, option.Option(dict.Dict(String, String))) ->
    response.Response(res)

pub type Node(req, res, ctx) {
  Node(
    handlers: dict.Dict(http.Method, Handler(req, res, ctx)),
    static: dict.Dict(String, Node(req, res, ctx)),
    param: option.Option(#(String, Node(req, res, ctx))),
  )
}

pub type Router(req, res, ctx) {
  Router(req: request.Request(req), root: Node(req, res, ctx), context: ctx)
}

pub fn new(req: request.Request(req), context: ctx) -> Router(req, res, ctx) {
  Router(req: req, root: empty_node(), context:)
}

fn empty_node() -> Node(req, res, ctx) {
  Node(handlers: dict.new(), static: dict.new(), param: option.None)
}

pub fn add(
  router: Router(req, res, ctx),
  method: http.Method,
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  let root = insert(router.root, split_path(path), method, handler)
  Router(..router, root:)
}

fn insert(
  node: Node(req, res, ctx),
  segments: List(String),
  method: http.Method,
  handler: Handler(req, res, ctx),
) -> Node(req, res, ctx) {
  case segments {
    [] -> Node(..node, handlers: dict.insert(node.handlers, method, handler))
    [segment, ..rest] ->
      case string.starts_with(segment, ":") {
        True -> {
          let name = string.drop_start(segment, 1)
          let child = case node.param {
            option.Some(#(_, existing)) -> existing
            option.None -> empty_node()
          }
          Node(
            ..node,
            param: option.Some(#(name, insert(child, rest, method, handler))),
          )
        }
        False -> {
          let child = case dict.get(node.static, segment) {
            Ok(existing) -> existing
            Error(_) -> empty_node()
          }
          Node(
            ..node,
            static: dict.insert(
              node.static,
              segment,
              insert(child, rest, method, handler),
            ),
          )
        }
      }
  }
}

pub fn match(
  router: Router(req, res, ctx),
  method: http.Method,
  path: String,
) -> option.Option(
  #(Handler(req, res, ctx), option.Option(dict.Dict(String, String))),
) {
  let node = walk(router.root, split_path(path), method, dict.new())

  case node |> option.is_some {
    True -> node
    False -> walk(router.root, ["not_found"], http.Get, dict.new())
  }
}

fn walk(
  node: Node(req, res, ctx),
  segments: List(String),
  method: http.Method,
  params: dict.Dict(String, String),
) -> option.Option(
  #(Handler(req, res, ctx), option.Option(dict.Dict(String, String))),
) {
  case segments {
    [] ->
      case dict.get(node.handlers, method) {
        Ok(handler) -> option.Some(#(handler, param_dict(params)))
        Error(_) -> option.None
      }
    [segment, ..rest] ->
      case dict.get(node.static, segment) {
        Ok(child) -> walk(child, rest, method, params)
        Error(_) ->
          case node.param {
            option.Some(#(name, child)) ->
              walk(child, rest, method, dict.insert(params, name, segment))
            option.None -> option.None
          }
      }
  }
}

fn param_dict(
  d: dict.Dict(String, String),
) -> option.Option(dict.Dict(String, String)) {
  case dict.size(d) {
    0 -> option.None
    _ -> option.Some(d)
  }
}

fn split_path(path: String) -> List(String) {
  path
  |> string.split("/")
  |> list.filter(fn(s) { s != "" })
}

//TODO: This is called when a request is made to the server. The router will consume the request and spit out the response
// FIXME: What happens if match provides nothing back? How do I perform some type of failure...or am I just always expecting some type of route?
pub fn consume(
  router: Router(req, res, ctx),
  req: request.Request(req),
) -> response.Response(res) {
  case match(router, req.method, req.path) {
    option.None -> todo
    option.Some -> todo
  }
}

pub fn get(
  router: Router(req, res, ctx),
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, http.Get, path, handler)
}

pub fn post(
  router: Router(req, res, ctx),
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, http.Post, path, handler)
}

pub fn put(
  router: Router(req, res, ctx),
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, http.Put, path, handler)
}

pub fn delete(
  router: Router(req, res, ctx),
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, http.Delete, path, handler)
}

pub fn patch(
  router: Router(req, res, ctx),
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, http.Patch, path, handler)
}

pub fn not_found(
  router: Router(req, res, ctx),
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, http.Get, "not_found", handler)
}
