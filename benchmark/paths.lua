-- paths.lua
-- Cycles requests through a mix of route shapes so the benchmark
-- exercises static routes, param routes, nested routes, and 404s
-- instead of hammering a single best-case path.
--
-- This list MUST match the route table registered in
-- simple_http_with_blazer.gleam / simple_http_with_pattern.gleam /
-- simple_http_with_fist.gleam. Every registered route gets a concrete
-- request here, plus one intentional 404.

paths = {
    "/",
    "/users/123",
    "/users/123/posts/456",
    "/health",
    "/status",
    "/ping",
    "/about",
    "/contact",
    "/feed",
    "/search",
    "/profile",
    "/settings",
    "/cart",
    "/checkout",
    "/login",
    "/logout",
    "/register",
    "/notifications",
    "/api/v1/health",
    "/api/v1/status",
    "/api/v1/metrics",
    "/products",
    "/orders",
    "/products/42",
    "/orders/7",
    "/orders/7/items",
    "/users/123/followers",
    "/does/not/exist"
}

request = function()
    local path = paths[math.random(#paths)]
    return wrk.format("GET", path)
end
