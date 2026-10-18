-- A tiny test runner shared by the test files (the one of Bulk Sell's tests).

local M = {}

function M.runner()
    local tests = {}
    local r = {}
    function r.test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end
    function r.run()
        local failed = 0
        for _, t in ipairs(tests) do
            local ok, err = pcall(t.fn)
            if ok then
                print("ok   " .. t.name)
            else
                failed = failed + 1
                print("FAIL " .. t.name .. ": " .. tostring(err))
            end
        end
        print(string.format("%d passed, %d failed", #tests - failed, failed))
        if failed > 0 then error("tests failed", 0) end
    end
    return r
end

function M.eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message or "value", tostring(expected), tostring(actual)), 2)
    end
end

return M
