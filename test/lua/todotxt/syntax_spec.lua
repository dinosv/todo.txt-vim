-- test/lua/todotxt/syntax_spec.lua
describe("todo syntax highlighting", function()
  local function setup_buffer(lines)
    vim.cmd("syntax on")
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "todo"
    return buf
  end

  local function group_at(lnum, col)
    return vim.fn.synIDattr(vim.fn.synID(lnum, col, true), "name")
  end

  it("highlights an active wf:1 task as TodoWaitingFor", function()
    setup_buffer({ "chase invoice wf:1 @UDD" })
    assert.equals("TodoWaitingFor", group_at(1, 1))
  end)

  it("highlights a completed wf:1 task as TodoDone, not TodoWaitingFor", function()
    setup_buffer({ "x 2026-07-13 chase invoice wf:1 @UDD" })
    assert.equals("TodoDone", group_at(1, 1))
  end)

  it("highlights a (D) task as TodoPriorityD", function()
    setup_buffer({ "(D) blocked task pid:42" })
    assert.equals("TodoPriorityD", group_at(1, 1))
  end)

  it("highlights lower priority letters through Z", function()
    setup_buffer({ "(Z) someday task" })
    assert.equals("TodoPriorityZ", group_at(1, 1))
  end)
end)
