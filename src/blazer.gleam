import blazer/tree
import gleam/http
import gleam/http/request
import gleam/list
import gleam/option
import gleam/result
import gleam/uri

pub type Handler(req, res, ctx) =
  tree.Handler(req, res, ctx)

pub type Node(req, res, ctx) =
  tree.Node(req, res, ctx)

pub type Router(req, res, ctx) {
  Router(root: Node(req, res, ctx), context: ctx)
}

pub fn new_with_context(context: ctx) -> Router(req, res, ctx) {
  Router(root: tree.empty_node(), context:)
}

pub fn new() -> Router(req, res, Nil) {
  Router(root: tree.empty_node(), context: Nil)
}

pub fn add(
  router: Router(req, res, ctx),
  method: http.Method,
  path: String,
  handler: Handler(req, res, ctx),
) -> Router(req, res, ctx) {
  let root = tree.insert(router.root, uri.path_segments(path), method, handler)

  Router(..router, root:)
}

pub fn consume(
  router: Router(req, res, ctx),
  req: request.Request(req),
  not_found_handler: Handler(req, res, ctx),
) -> res {
  let #(handler, params) =
    tree.walk(router.root, uri.path_segments(req.path), req.method, option.None)
    |> option.unwrap(or: #(not_found_handler, option.None))

  case handler {
    tree.WithParams(with_params_handler) ->
      with_params_handler(req, router.context, params |> option.unwrap(or: []))
    tree.WithoutParams(without_params_handler) ->
      without_params_handler(req, router.context)
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

pub fn handler(
  handler: fn(request.Request(req), ctx) -> res,
) -> Handler(req, res, ctx) {
  tree.WithoutParams(handler)
}

pub fn handler_with_params(
  handler: fn(request.Request(req), ctx, List(#(String, String))) -> res,
) -> Handler(req, res, ctx) {
  tree.WithParams(handler)
}

pub fn get_param(params: List(#(String, String)), key: String) -> String {
  list.key_find(params, key) |> result.unwrap(or: "")
}
