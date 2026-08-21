-- paths.lua
-- Cycles requests through a mix of route shapes so the benchmark
-- exercises static routes, param routes, nested routes, and 404s
-- instead of hammering a single best-case path.
--
-- Edit this list to match your actual route table.

paths = {
    "/",
    "/users/123",
    "/users/123/posts/456",
    "/does/not/exist"
}

request = function()
    local path = paths[math.random(#paths)]
    return wrk.format("GET", path)
end
