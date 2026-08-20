import blazer/tree
import gleam/dict
import gleam/http
import gleam/http/request
import gleam/option

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
  let root = tree.insert(router.root, tree.split_path(path), method, handler)

  Router(..router, root:)
}

pub fn match(
  router: Router(req, res, ctx),
  method: http.Method,
  path: String,
) -> option.Option(
  #(Handler(req, res, ctx), option.Option(dict.Dict(String, String))),
) {
  tree.walk(router.root, tree.split_path(path), method, option.None)
}

pub fn consume(
  router: Router(req, res, ctx),
  req: request.Request(req),
  not_found_handler: Handler(req, res, ctx),
) -> res {
  let #(handler, params) =
    match(router, req.method, req.path)
    |> option.unwrap(or: #(not_found_handler, option.None))

  handler(req, router.context, params)
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
