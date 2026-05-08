-- Unit tests for lua/lars/dap_exception_picker.lua
-- Covers the file-parser used by async ripgrep discovery:
--   - block-scoped namespace declarations
--   - file-scoped namespace declarations
--   - multiple namespaces in one file
--   - exception names that share a prefix with non-exception
--     types (e.g. ExceptionHandler should NOT match)
local picker = require("lars.dap_exception_picker")

local testroot =
	vim.fn.stdpath("config") .. "/tests/.tmp_exc_picker"

describe("dap_exception_picker._extract_from_file", function()
	before_each(function()
		vim.fn.delete(testroot, "rf")
		vim.fn.mkdir(testroot, "p")
	end)

	after_each(function()
		vim.fn.delete(testroot, "rf")
	end)

	local function write(name, lines)
		local path = testroot .. "/" .. name
		vim.fn.writefile(lines, path)
		return path
	end

	it("extracts a single class with block-scoped namespace",
		function()
			local f = write("Foo.cs", {
				"namespace MyApp.Errors {",
				"    public class FooException : Exception {",
				"    }",
				"}",
			})
			local got = picker._extract_from_file(f)
			assert.are.same({ "MyApp.Errors.FooException" }, got)
		end)

	it("extracts with file-scoped namespace", function()
		local f = write("Bar.cs", {
			"namespace MyApp.Data;",
			"",
			"public class BarException : ApplicationException",
			"{",
			"}",
		})
		local got = picker._extract_from_file(f)
		assert.are.same({ "MyApp.Data.BarException" }, got)
	end)

	it("returns unqualified name when no namespace", function()
		local f = write("Baz.cs", {
			"public class BazException : Exception {}",
		})
		local got = picker._extract_from_file(f)
		assert.are.same({ "BazException" }, got)
	end)

	it("handles multiple namespaces in one file", function()
		local f = write("Multi.cs", {
			"namespace A {",
			"    public class AlphaException : Exception {} ",
			"}",
			"namespace B {",
			"    public class BetaException : Exception {} ",
			"}",
		})
		local got = picker._extract_from_file(f)
		assert.are.same(
			{ "A.AlphaException", "B.BetaException" }, got)
	end)

	it("does NOT match types that merely contain Exception",
		function()
			local f = write("Handler.cs", {
				"namespace X;",
				"public class ExceptionHandler {}",
				"public class FooExceptionFilter {}",
			})
			local got = picker._extract_from_file(f)
			assert.are.same({}, got)
		end)

	it("matches multiple classes in same namespace", function()
		local f = write("Many.cs", {
			"namespace Errors;",
			"public class OneException : Exception {}",
			"public class TwoException : Exception {}",
		})
		local got = picker._extract_from_file(f)
		assert.are.same(
			{ "Errors.OneException", "Errors.TwoException" },
			got)
	end)

	it("returns empty list for missing file", function()
		local got = picker._extract_from_file(
			testroot .. "/does_not_exist.cs")
		assert.are.same({}, got)
	end)
end)
