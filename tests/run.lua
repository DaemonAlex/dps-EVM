-- lua5.4 tests/run.lua  (run from the resource root)
-- Loads shared/*.lua with no FiveM natives and runs every tests/test_*.lua.
package.path = './?.lua;./shared/?.lua;./tests/?.lua;' .. package.path

local passed, failed = 0, 0
function check(name, ok, detail)
    if ok then passed = passed + 1
    else failed = failed + 1; print(('  FAIL %s%s'):format(name, detail and (' -> ' .. tostring(detail)) or '')) end
end
function eq(name, got, want)
    check(name, got == want, ('got %s want %s'):format(tostring(got), tostring(want)))
end

dofile('shared/fields.lua')
dofile('shared/groups.lua')
dofile('shared/workshop.lua')
dofile('shared/search.lua')

local files = { 'tests/test_search.lua', 'tests/test_card.lua', 'tests/test_sections.lua', 'tests/test_access.lua', 'tests/test_workshop.lua' }
for _, f in ipairs(files) do
    print('== ' .. f)
    local ok, err = pcall(dofile, f)
    if not ok then failed = failed + 1; print('  ERROR ' .. tostring(err)) end
end
print(('%d passed, %d failed'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
