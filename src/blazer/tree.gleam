import gleam/dict
import gleam/http
import gleam/http/request
import gleam/option
import gleam/string

pub type Handler(req, res, ctx) =
  fn(request.Request(req), ctx, dict.Dict(String, String)) -> res

pub type Node(req, res, ctx) {
  Node(
    handlers: dict.Dict(http.Method, Handler(req, res, ctx)),
    static: dict.Dict(String, Node(req, res, ctx)),
    param: option.Option(#(String, Node(req, res, ctx))),
  )
}

pub fn empty_node() -> Node(req, res, ctx) {
  Node(handlers: dict.new(), static: dict.new(), param: option.None)
}

pub fn insert(
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

pub fn walk(
  node: Node(req, res, ctx),
  segments: List(String),
  method: http.Method,
  params: option.Option(dict.Dict(String, String)),
) -> option.Option(
  #(Handler(req, res, ctx), option.Option(dict.Dict(String, String))),
) {
  case segments {
    [] ->
      case dict.get(node.handlers, method) {
        Ok(handler) -> option.Some(#(handler, params))
        Error(_) -> option.None
      }
    [segment, ..rest] ->
      case dict.get(node.static, segment) {
        Ok(child) -> walk(child, rest, method, params)
        Error(_) ->
          case node.param {
            option.Some(#(name, child)) -> {
              case params {
                option.Some(params) ->
                  walk(
                    child,
                    rest,
                    method,
                    option.Some(dict.insert(params, name, segment)),
                  )
                option.None ->
                  walk(
                    child,
                    rest,
                    method,
                    option.Some(dict.insert(dict.new(), name, segment)),
                  )
              }
            }
            option.None -> option.None
          }
      }
  }
}

pub fn param_dict(
  d: dict.Dict(String, String),
) -> option.Option(dict.Dict(String, String)) {
  case dict.size(d) {
    0 -> option.None
    _ -> option.Some(d)
  }
}
