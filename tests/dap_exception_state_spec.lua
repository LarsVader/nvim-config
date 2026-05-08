-- Tests for lua/lars/dap_exception_state.lua persistent
-- exception-types store. Each test uses a unique temp file
-- via the M._path override so we don't touch the real
-- ~/AppData/Local/nvim-data file.
local state = require("lars.dap_exception_state")

local testroot =
	vim.fn.stdpath("config") .. "/tests/.tmp_exc_state"
local original_path

describe("dap_exception_state", function()
	before_each(function()
		vim.fn.delete(testroot, "rf")
		vim.fn.mkdir(testroot, "p")
		original_path = state._path
		state._path = function()
			return testroot .. "/exc.json"
		end
	end)

	after_each(function()
		state._path = original_path
		vim.fn.delete(testroot, "rf")
	end)

	it("returns empty list when file is missing", function()
		assert.are.same({}, state.get("/some/cwd"))
	end)

	it("round-trips a single cwd", function()
		state.set(
			{ "System.IOException" }, "/proj/a")
		assert.are.same(
			{ "System.IOException" }, state.get("/proj/a"))
	end)

	it("keeps cwds independent", function()
		state.set({ "System.A" }, "/proj/a")
		state.set({ "System.B", "System.C" }, "/proj/b")
		assert.are.same(
			{ "System.A" }, state.get("/proj/a"))
		assert.are.same(
			{ "System.B", "System.C" },
			state.get("/proj/b"))
	end)

	it("set with empty list clears the cwd's entry",
		function()
			state.set({ "System.X" }, "/proj/c")
			assert.are.same(
				{ "System.X" }, state.get("/proj/c"))
			state.set({}, "/proj/c")
			assert.are.same({}, state.get("/proj/c"))
			-- Other cwds untouched.
			state.set({ "System.A" }, "/proj/d")
			state.set({}, "/proj/c")
			assert.are.same(
				{ "System.A" }, state.get("/proj/d"))
		end)

	it("survives a fresh read after writing", function()
		state.set(
			{ "System.NullReferenceException" },
			"/proj/e")
		-- Read back via a brand-new module table to simulate
		-- nvim restart (read_all is closed-over but fully
		-- re-runs on each call so this is equivalent).
		assert.are.same(
			{ "System.NullReferenceException" },
			state.get("/proj/e"))
	end)

	it("treats corrupt file as empty without crashing",
		function()
			vim.fn.writefile(
				{ "{ this is not json" },
				testroot .. "/exc.json")
			-- vim.notify is stubbed by plenary; just assert
			-- the call returns empty and doesn't throw.
			assert.are.same({}, state.get("/proj/x"))
		end)

	it("filters non-string entries on read", function()
		-- Write a JSON file with a mixed-type list.
		vim.fn.writefile(
			{
				vim.json.encode({
					["/proj/y"] = {
						types = {
							"System.A", 42, "System.B",
						},
					},
				}),
			},
			testroot .. "/exc.json")
		assert.are.same(
			{ "System.A", "System.B" },
			state.get("/proj/y"))
	end)
end)
