import gleam/dict
import gleam/list
import gleam/option
import gleam/string

pub type Method {
  Get
  Post
  Put
  Delete
  Patch
}

pub type Handler(req, res, ctx) =
  fn(req, ctx, option.Option(dict.Dict(String, String))) -> res

pub type Node(req, res, ctx) {
  Node(
    handlers: dict.Dict(Method, Handler(req, res, ctx)),
    static: dict.Dict(String, Node(req, res, ctx)),
    param: option.Option(#(String, Node(req, res, ctx))),
  )
}

pub type Router(req, res, ctx) {
  Router(root: Node(req, res, ctx), context: ctx)
}

pub fn new(context: ctx) -> Router(req, res, ctx) {
  Router(root: empty_node(), context:)
}

fn empty_node() -> Node(req, res, ctx) {
  Node(handlers: dict.new(), static: dict.new(), param: option.None)
}

pub fn add(
  router: Router(req, res, ctx),
  method: Method,
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  let root = insert(router.root, split_path(path), method, handler)
  Router(..router, root:)
}

fn insert(
  node: Node(req, res, ctx),
  segments: List(String),
  method: Method,
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
  method: Method,
  path: String,
) -> option.Option(
  #(Handler(req, res, ctx), option.Option(dict.Dict(String, String))),
) {
  walk(router.root, split_path(path), method, dict.new())
}

fn walk(
  node: Node(req, res, ctx),
  segments: List(String),
  method: Method,
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

pub fn get(
  router: Router(req, res, ctx),
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, Get, path, handler)
}

pub fn post(
  router: Router(req, res, ctx),
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, Post, path, handler)
}

pub fn put(
  router: Router(req, res, ctx),
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, Put, path, handler)
}

pub fn delete(
  router: Router(req, res, ctx),
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, Delete, path, handler)
}

pub fn patch(
  router: Router(req, res, ctx),
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  add(router, Patch, path, handler)
}
