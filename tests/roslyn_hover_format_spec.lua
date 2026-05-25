-- Tests for lars.roslyn_hover_format.split — splits Roslyn's hover
-- markdown into (signature paragraph lines, rest lines). Signature lines
-- come back with markdown punctuation unescaped (e.g. `\<` → `<`) so the
-- caller can drop them into a noice message as raw text and apply
-- ft-syntax over them directly.

local split = require("lars.roslyn_hover_format").split

describe("roslyn_hover_format.split", function()
	it("splits signature paragraph from body on first blank line", function()
		local sig, rest = split("Type[] System.Reflection.Assembly.GetTypes()\n\nGets all types defined in this assembly.")
		assert.same({ "Type[] System.Reflection.Assembly.GetTypes()" }, sig)
		assert.same({ "", "Gets all types defined in this assembly." }, rest)
	end)

	it("strips Roslyn's ```csharp ... ``` fence around the signature", function()
		local sig, rest = split("```csharp\n(extension) IEnumerable<Type> Where<Type>(Func<Type, bool> predicate)\n```\n\nFilters a sequence.")
		assert.same({ "(extension) IEnumerable<Type> Where<Type>(Func<Type, bool> predicate)" }, sig)
		assert.same({ "", "Filters a sequence." }, rest)
	end)

	it("strips a bare ``` fence (no language tag) around the signature", function()
		local sig, rest = split("```\nvoid M()\n```\n\nbody")
		assert.same({ "void M()" }, sig)
		assert.same({ "", "body" }, rest)
	end)

	it("strips both fences when the entire content is just a fenced signature", function()
		local sig, rest = split("```csharp\nvoid M()\n```")
		assert.same({ "void M()" }, sig)
		assert.same({}, rest)
	end)

	it("unescapes all markdown punctuation in signature lines", function()
		local sig = split("IEnumerable\\<Type\\> Where\\<Type\\>(Func\\<Type, bool\\> predicate)\n\nbody")
		assert.same({ "IEnumerable<Type> Where<Type>(Func<Type, bool> predicate)" }, sig)
	end)

	it("unescapes only angle brackets in body lines (other escapes survive for noice)", function()
		local _, rest = split("void M()\n\nReturns:\n  An IEnumerable\\<T\\> plus a literal \\*asterisk\\* and a \\`tick\\`.")
		assert.is_truthy(rest[3]:find("An IEnumerable<T> plus", 1, true))
		assert.is_truthy(rest[3]:find("\\*asterisk\\*", 1, true))
		assert.is_truthy(rest[3]:find("\\`tick\\`", 1, true))
	end)

	it("returns a multi-line signature paragraph as separate lines", function()
		local sig, rest = split("(extension) IEnumerable<Type>\n  .Where<Type>(Func<Type, bool> predicate)\n\nbody")
		assert.same({ "(extension) IEnumerable<Type>", "  .Where<Type>(Func<Type, bool> predicate)" }, sig)
		assert.same({ "", "body" }, rest)
	end)

	it("collapses CRLF before splitting", function()
		local sig, rest = split("void M()\r\n\r\nDoes a thing.\r\n")
		assert.same({ "void M()" }, sig)
		assert.same({ "", "Does a thing.", "" }, rest)
	end)

	it("returns an empty signature when content starts with a blank line", function()
		local sig, rest = split("\n\nbody")
		assert.same({}, sig)
		assert.is_truthy(#rest > 0)
	end)

	it("treats a signature-only input as all signature, no rest", function()
		local sig, rest = split("void M()")
		assert.same({ "void M()" }, sig)
		assert.same({}, rest)
	end)

	it("returns empty tables for empty or non-string input", function()
		local sig, rest = split("")
		assert.same({}, sig)
		assert.same({}, rest)

		sig, rest = split(nil)
		assert.same({}, sig)
		assert.same({}, rest)
	end)
end)
