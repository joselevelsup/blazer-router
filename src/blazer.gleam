import blazer/tree
import gleam/dict
import gleam/http
import gleam/http/request
import gleam/option

pub type Handler(req, res, ctx) =
  tree.Handler(req, res, ctx)

pub type Node(req, res, ctx) =
  tree.Node(req, res, ctx)

pub type MiddlewareFunc(req, res, ctx) {
  MiddlewareFunc(req, res, ctx, next: Handler(req, res, ctx))
}

pub type Router(req, res, ctx) {
  Router(
    root: tree.Node(req, res, ctx),
    context: ctx,
    middleware: option.Option(dict.Dict(String, MiddlewareFunc)),
  )
}

pub fn new_with_context(context: ctx) -> Router(req, res, ctx) {
  Router(root: tree.empty_node(), context:, middleware: option.None)
}

pub fn new() -> Router(req, res, Nil) {
  Router(root: tree.empty_node(), context: Nil, middleware: option.None)
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

pub fn define_middleware(
  router: Router(req, res, ctx),
  name: String,
  func: MiddlewareFunc(req, res, ctx),
) -> Router(req, res, ctx) {
  let middleware =
    router.middleware
    |> option.unwrap(or: dict.new())
    |> dict.upsert(name, fn(key) {
      case key {
        option.Some(current_func) -> current_func
        option.None -> func
      }
    })

  Router(..router, middleware: option.Some(middleware))
}

pub fn use_middleware(
  router: Router(req, res, ctx),
  name: String,
  main_handler: Handler(req, res, ctx),
) -> res {
  let middleware_handler = case router.middleware {
    option.Some(middleware_dict) ->
      case dict.get(middleware_dict, name) {
        Ok(middleware_handler) -> middleware_handler
        Error(_) -> todo
      }
    option.None -> todo
  }
  fn(req: req, ctx: ctx, params: option.Option(dict.Dict(String, String))) -> res {
    middleware_handler(req, ctx, handler)
  }
}

pub fn match(
  router: Router(req, res, ctx),
  method: http.Method,
  path: String,
) -> option.Option(
  #(Handler(req, res, ctx), option.Option(dict.Dict(String, String))),
) {
  tree.walk(router.root, tree.split_path(path), method, dict.new())
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
