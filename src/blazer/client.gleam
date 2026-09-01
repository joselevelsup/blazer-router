import blazer
import blazer/tree
import gleam/http
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub fn generate(
  router: blazer.Router(req, res, ctx),
  file_path: String,
) -> Result(Nil, String) {
  let functions =
    tree.gather(router.root, [], [])
    |> list.map(route_source)
    |> string.join("\n\n")

  let file_path = case string.ends_with(file_path, ".gleam") {
    True -> file_path
    False -> file_path <> ".gleam"
  }

  let code =
    "import gleam/http\nimport gleam/http/request\n\n" <> functions <> "\n"

  simplifile.write(file_path, code)
  |> result.map_error(fn(err) {
    "Could not write client code to "
    <> file_path
    <> ": "
    <> simplifile.describe_error(err)
  })
}

fn route_source(route: #(List(String), http.Method)) -> String {
  let #(segments, method) = route
  let method_ctor = string.capitalise(http.method_to_string(method))
  let args = [
    "base: String",
    ..list.filter_map(segments, fn(segment) {
      case string.starts_with(segment, ":") {
        True -> Ok(string.drop_start(segment, 1) <> ": String")
        False -> Error(Nil)
      }
    })
  ]

  "pub fn "
  <> fn_name(segments, method)
  <> "("
  <> string.join(args, ", ")
  <> ") -> request.Request(String) {\n"
  <> "  request.new()\n"
  <> "  |> request.set_method(http."
  <> method_ctor
  <> ")\n"
  <> "  |> request.set_path("
  <> path_expr(segments)
  <> ")\n"
  <> "}"
}

fn fn_name(segments: List(String), method: http.Method) -> String {
  let prefix = string.lowercase(http.method_to_string(method))
  case segments {
    [] -> prefix
    _ -> prefix <> "_" <> string.join(list.map(segments, strip_colon), "_")
  }
}

fn strip_colon(segment: String) -> String {
  case string.starts_with(segment, ":") {
    True -> string.drop_start(segment, 1)
    False -> segment
  }
}

type Part {
  Lit(String)
  Arg(String)
}

fn path_expr(segments: List(String)) -> String {
  // Merge consecutive static segments into one string literal,
  // params become string concatenation arguments.
  let #(parts, _) =
    list.fold(segments, #([], False), fn(acc, segment) {
      let #(parts, prev_lit) = acc
      case string.starts_with(segment, ":") {
        True -> {
          let name = strip_colon(segment)
          let parts = case prev_lit, parts {
            True, [Lit(content), ..rest] -> [
              Arg(name),
              Lit(content <> "/"),
              ..rest
            ]
            _, _ -> [Arg(name), Lit("/"), ..parts]
          }
          #(parts, False)
        }
        False -> {
          let parts = case prev_lit, parts {
            True, [Lit(content), ..rest] -> [
              Lit(content <> "/" <> segment),
              ..rest
            ]
            _, _ -> [Lit("/" <> segment), ..parts]
          }
          #(parts, True)
        }
      }
    })

  let rendered =
    list.reverse(parts)
    |> list.map(fn(part) {
      case part {
        Lit(content) -> "\"" <> content <> "\""
        Arg(name) -> name
      }
    })

  string.join(["base", ..rendered], " <> ")
}
