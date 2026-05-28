-- Tests for lars.cppcli_user_files — the pure-logic helpers that drive
-- the per-csproj `.user` generation. The MSBuild call (_query_vcxproj_output)
-- and the filesystem scan are exercised by the manual smoke test against
-- the mixdbg repo, not here.

local m = require("lars.cppcli_user_files")

describe("cppcli_user_files._parse_csproj", function()
    it("finds vcxproj ProjectReferences (single-line)", function()
        local xml = [[
<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <ProjectReference Include="..\CliWrapper\CliWrapper.vcxproj" />
  </ItemGroup>
</Project>
]]
        local r = m._parse_csproj(xml)
        assert.same({ "..\\CliWrapper\\CliWrapper.vcxproj" }, r.vcxproj_refs)
    end)

    it("finds vcxproj ProjectReferences (multi-line with child elements)", function()
        local xml = [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\LateCliWrapper\LateCliWrapper.vcxproj">
      <ReferenceOutputAssembly>false</ReferenceOutputAssembly>
    </ProjectReference>
  </ItemGroup>
</Project>
]]
        local r = m._parse_csproj(xml)
        assert.same({ "..\\LateCliWrapper\\LateCliWrapper.vcxproj" }, r.vcxproj_refs)
    end)

    it("ignores non-vcxproj ProjectReferences", function()
        local xml = [[
<Project>
  <ProjectReference Include="..\Other\Other.csproj" />
  <ProjectReference Include="..\Cpp\Cpp.vcxproj" />
</Project>
]]
        local r = m._parse_csproj(xml)
        assert.same({ "..\\Cpp\\Cpp.vcxproj" }, r.vcxproj_refs)
    end)

    it("converts forward slashes in Include to backslashes", function()
        local xml = '<Project><ProjectReference Include="../foo/Bar.vcxproj" /></Project>'
        local r = m._parse_csproj(xml)
        assert.same({ "..\\foo\\Bar.vcxproj" }, r.vcxproj_refs)
    end)

    it("collects existing <Reference> assembly names (strips version qualifier)", function()
        local xml = [[
<Project>
  <ItemGroup>
    <Reference Include="LateCliWrapper">
      <HintPath>..\x64\Debug\LateCliWrapper.dll</HintPath>
    </Reference>
    <Reference Include="System.Xml, Version=4.0.0.0, Culture=neutral" />
  </ItemGroup>
</Project>
]]
        local r = m._parse_csproj(xml)
        assert.is_true(r.existing_refs["LateCliWrapper"])
        assert.is_true(r.existing_refs["System.Xml"])
    end)

    it("works with SDK-style xmlns attribute on Project", function()
        local xml = [[
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup>
    <ProjectReference Include="..\Cpp\Cpp.vcxproj" />
    <Reference Include="System" />
  </ItemGroup>
</Project>
]]
        local r = m._parse_csproj(xml)
        assert.same({ "..\\Cpp\\Cpp.vcxproj" }, r.vcxproj_refs)
        assert.is_true(r.existing_refs["System"])
    end)

    it("returns empty tables for csproj without any references", function()
        local r = m._parse_csproj("<Project><PropertyGroup/></Project>")
        assert.same({}, r.vcxproj_refs)
        assert.same({}, r.existing_refs)
    end)
end)

describe("cppcli_user_files._compute_relative_path", function()
    it("walks up the right number of directories", function()
        local rel = m._compute_relative_path(
            "D:\\repo\\src\\WpfApp",
            "D:\\repo\\src\\CliWrapper\\x64\\Debug\\CliWrapper.dll"
        )
        assert.equals("..\\CliWrapper\\x64\\Debug\\CliWrapper.dll", rel)
    end)

    it("handles file directly under from_dir", function()
        local rel = m._compute_relative_path(
            "D:\\repo\\src\\WpfApp",
            "D:\\repo\\src\\WpfApp\\out\\Foo.dll"
        )
        assert.equals("out\\Foo.dll", rel)
    end)

    it("walks up multiple levels", function()
        local rel = m._compute_relative_path(
            "D:\\repo\\src\\a\\b\\c",
            "D:\\repo\\x64\\Debug\\Foo.dll"
        )
        assert.equals("..\\..\\..\\..\\x64\\Debug\\Foo.dll", rel)
    end)

    it("is case-insensitive on the prefix (Windows path semantics)", function()
        local rel = m._compute_relative_path(
            "d:\\repo\\Src\\WpfApp",
            "D:\\Repo\\src\\CliWrapper\\Out.dll"
        )
        assert.equals("..\\CliWrapper\\Out.dll", rel)
    end)

    it("normalizes forward slashes in either argument", function()
        local rel = m._compute_relative_path(
            "D:/repo/src/WpfApp",
            "D:/repo/src/CliWrapper/Out.dll"
        )
        assert.equals("..\\CliWrapper\\Out.dll", rel)
    end)
end)

describe("cppcli_user_files._build_user_xml", function()
    it("emits a Project with the DesignTimeBuild condition", function()
        local xml = m._build_user_xml({
            { name = "CliWrapper", hint = "..\\out\\CliWrapper.dll" },
        })
        assert.is_truthy(xml:find("<Project>", 1, true))
        assert.is_truthy(xml:find("'%$%(DesignTimeBuild%)' == 'true'"))
        assert.is_truthy(xml:find('<Reference Include="CliWrapper">', 1, true))
        assert.is_truthy(xml:find("<HintPath>..\\out\\CliWrapper.dll</HintPath>", 1, true))
        assert.is_truthy(xml:find("<Private>false</Private>", 1, true))
        assert.is_truthy(xml:find("</Project>", 1, true))
    end)

    it("emits one <Reference> per entry", function()
        local xml = m._build_user_xml({
            { name = "A", hint = "a.dll" },
            { name = "B", hint = "b.dll" },
        })
        local count = 0
        for _ in xml:gmatch('<Reference Include="') do count = count + 1 end
        assert.equals(2, count)
    end)
end)

describe("cppcli_user_files._needs_regen", function()
    local tmp_csproj
    local tmp_user

    before_each(function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        tmp_csproj = dir .. "/Foo.csproj"
        tmp_user = dir .. "/Foo.csproj.user"
    end)

    after_each(function()
        pcall(os.remove, tmp_csproj)
        pcall(os.remove, tmp_user)
    end)

    it("regens when the .user is missing", function()
        local f = io.open(tmp_csproj, "w"); f:write("<Project/>"); f:close()
        assert.is_true(m._needs_regen(tmp_csproj, tmp_user))
    end)

    it("regens when the csproj is newer than the .user", function()
        local f = io.open(tmp_user, "w"); f:write("<Project/>"); f:close()
        -- Sleep enough for filesystem mtime resolution (typically 1s on FAT/older NTFS)
        vim.uv.sleep(1100)
        f = io.open(tmp_csproj, "w"); f:write("<Project/>"); f:close()
        assert.is_true(m._needs_regen(tmp_csproj, tmp_user))
    end)

    it("skips when the .user is newer than the csproj", function()
        local f = io.open(tmp_csproj, "w"); f:write("<Project/>"); f:close()
        vim.uv.sleep(1100)
        f = io.open(tmp_user, "w"); f:write("<Project/>"); f:close()
        assert.is_false(m._needs_regen(tmp_csproj, tmp_user))
    end)

    it("regens when a HintPath in the existing .user points at a missing file", function()
        local f = io.open(tmp_csproj, "w"); f:write("<Project/>"); f:close()
        vim.uv.sleep(1100)
        f = io.open(tmp_user, "w")
        f:write([[
<Project>
  <ItemGroup>
    <Reference Include="Phantom">
      <HintPath>does\not\exist.dll</HintPath>
    </Reference>
  </ItemGroup>
</Project>
]]); f:close()
        local csproj_dir = vim.fs.dirname(tmp_csproj)
        assert.is_true(m._needs_regen(tmp_csproj, tmp_user, csproj_dir))
    end)

    it("skips when all HintPaths in the .user point at existing files", function()
        local csproj_dir = vim.fs.dirname(tmp_csproj)
        -- Create a real DLL the HintPath can point at
        local dll = csproj_dir .. "/real.dll"
        local f = io.open(dll, "w"); f:write(""); f:close()

        f = io.open(tmp_csproj, "w"); f:write("<Project/>"); f:close()
        vim.uv.sleep(1100)
        f = io.open(tmp_user, "w")
        f:write([[
<Project>
  <ItemGroup>
    <Reference Include="Real">
      <HintPath>real.dll</HintPath>
    </Reference>
  </ItemGroup>
</Project>
]]); f:close()
        assert.is_false(m._needs_regen(tmp_csproj, tmp_user, csproj_dir))
        pcall(os.remove, dll)
    end)
end)

describe("cppcli_user_files._all_hint_paths_exist", function()
    local dir
    local user_path

    before_each(function()
        dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        user_path = dir .. "/Foo.csproj.user"
    end)

    after_each(function()
        pcall(os.remove, user_path)
    end)

    it("returns false when the .user is missing", function()
        assert.is_false(m._all_hint_paths_exist(user_path, dir))
    end)

    it("returns false when any relative HintPath is missing", function()
        local f = io.open(user_path, "w")
        f:write([[<Project><HintPath>nope.dll</HintPath></Project>]])
        f:close()
        assert.is_false(m._all_hint_paths_exist(user_path, dir))
    end)

    it("returns true when all relative HintPaths exist", function()
        local f = io.open(dir .. "/a.dll", "w"); f:write(""); f:close()
        f = io.open(user_path, "w")
        f:write([[<Project><HintPath>a.dll</HintPath></Project>]])
        f:close()
        assert.is_true(m._all_hint_paths_exist(user_path, dir))
        pcall(os.remove, dir .. "/a.dll")
    end)

    it("treats a .user with no HintPaths as valid", function()
        local f = io.open(user_path, "w"); f:write("<Project/>"); f:close()
        assert.is_true(m._all_hint_paths_exist(user_path, dir))
    end)

    it("handles absolute HintPaths (skips csproj_dir join)", function()
        local abs = dir .. "/x.dll"
        local f = io.open(abs, "w"); f:write(""); f:close()
        f = io.open(user_path, "w")
        -- `dir` from `vim.fn.tempname()` is a Windows-shaped absolute path
        -- (drive-letter root). vim.fs.normalize handles the mixed slashes.
        f:write("<Project><HintPath>" .. abs .. "</HintPath></Project>")
        f:close()
        assert.is_true(m._all_hint_paths_exist(user_path, "C:\\unrelated"))
        pcall(os.remove, abs)
    end)
end)

describe("cppcli_user_files._parse_csproj XML comment handling", function()
    it("ignores commented-out ProjectReferences", function()
        local xml = [[
<Project>
  <!-- <ProjectReference Include="..\Stub\Stub.vcxproj" /> -->
  <ProjectReference Include="..\Real\Real.vcxproj" />
</Project>
]]
        local r = m._parse_csproj(xml)
        assert.same({ "..\\Real\\Real.vcxproj" }, r.vcxproj_refs)
    end)

    it("ignores commented-out <Reference> entries", function()
        local xml = [[
<Project>
  <!-- <Reference Include="OldName" /> -->
  <Reference Include="ActiveName" />
</Project>
]]
        local r = m._parse_csproj(xml)
        assert.is_nil(r.existing_refs["OldName"])
        assert.is_true(r.existing_refs["ActiveName"])
    end)

    it("handles multi-line comment blocks", function()
        local xml = [[
<Project>
  <!--
    <ProjectReference Include="..\Stub\Stub.vcxproj" />
    <Reference Include="OldName" />
  -->
  <ProjectReference Include="..\Real\Real.vcxproj" />
</Project>
]]
        local r = m._parse_csproj(xml)
        assert.same({ "..\\Real\\Real.vcxproj" }, r.vcxproj_refs)
        assert.is_nil(r.existing_refs["OldName"])
    end)
end)

describe("cppcli_user_files._scan", function()
    local root

    before_each(function()
        m._reset_for_test()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
    end)

    after_each(function()
        pcall(vim.fn.delete, root, "rf")
    end)

    local function touch(rel)
        local full = root .. "/" .. rel
        vim.fn.mkdir(vim.fs.dirname(full), "p")
        local f = io.open(full, "w"); f:write(""); f:close()
        return full
    end

    local function norm_set(t)
        local out = {}
        for _, v in ipairs(t) do table.insert(out, vim.fs.normalize(v)) end
        table.sort(out)
        return out
    end

    it("returns an empty sln_dirs list when no .sln present", function()
        touch("Foo/Foo.csproj")
        touch("Bar/Bar.vcxproj")
        local csprojs, has_vcx, sln_dirs = m._scan(root)
        assert.equals(1, #csprojs)
        assert.is_true(has_vcx)
        assert.same({}, sln_dirs)
    end)

    it("returns the workspace_root as the sln_dir when .sln is at the root", function()
        touch("Top.sln")
        touch("Foo/Foo.csproj")
        touch("Bar/Bar.vcxproj")
        local _, _, sln_dirs = m._scan(root)
        assert.same({ vim.fs.normalize(root) }, norm_set(sln_dirs))
    end)

    it("finds .sln nested one level deep (reviewer's #4 regression)", function()
        touch("src/Sub.sln")
        touch("src/Foo/Foo.csproj")
        touch("src/Bar/Bar.vcxproj")
        local _, _, sln_dirs = m._scan(root)
        assert.same({ vim.fs.normalize(root .. "/src") }, norm_set(sln_dirs))
    end)

    it("returns every .sln so the caller can pick per-csproj nearest ancestor", function()
        touch("deep/inner/Deep.sln")
        touch("Top.sln")
        touch("Foo/Foo.csproj")
        touch("Bar/Bar.vcxproj")
        local _, _, sln_dirs = m._scan(root)
        assert.same(
            norm_set({ root, root .. "/deep/inner" }),
            norm_set(sln_dirs)
        )
    end)

    it("accepts .slnx in place of .sln", function()
        touch("Top.slnx")
        touch("Foo/Foo.csproj")
        touch("Bar/Bar.vcxproj")
        local _, _, sln_dirs = m._scan(root)
        assert.same({ vim.fs.normalize(root) }, norm_set(sln_dirs))
    end)

    it("ignores .sln inside skipped noise dirs (.git, bin, obj)", function()
        touch(".git/should_not_count.sln")
        touch("bin/also_not.sln")
        touch("Foo/Foo.csproj")
        touch("Bar/Bar.vcxproj")
        local _, _, sln_dirs = m._scan(root)
        assert.same({}, sln_dirs)
    end)

    it("sorts sln_dirs shallowest-first, then alphabetically", function()
        touch("Top.sln")
        touch("a/Inner.sln")
        touch("z/Inner.sln")
        touch("a/b/Deep.sln")
        touch("Foo/Foo.vcxproj")
        local _, _, sln_dirs = m._scan(root)
        local n = vim.fs.normalize
        assert.equals(n(root), n(sln_dirs[1]))
        assert.equals(n(root .. "/a"), n(sln_dirs[2]))
        assert.equals(n(root .. "/z"), n(sln_dirs[3]))
        assert.equals(n(root .. "/a/b"), n(sln_dirs[4]))
    end)
end)

describe("cppcli_user_files._nearest_sln_dir", function()
    it("picks the deepest .sln directory that is an ancestor of the csproj", function()
        local sln_dirs = {
            "D:/repo",
            "D:/repo/src",
        }
        local best = m._nearest_sln_dir("D:/repo/src/Foo/Foo.csproj", sln_dirs)
        assert.equals("D:/repo/src", best)
    end)

    it("returns nil when no candidate is an ancestor", function()
        local sln_dirs = { "D:/somewhere/else" }
        local best = m._nearest_sln_dir("D:/repo/src/Foo/Foo.csproj", sln_dirs)
        assert.is_nil(best)
    end)

    it("returns nil when sln_dirs is empty", function()
        assert.is_nil(m._nearest_sln_dir("D:/repo/Foo/Foo.csproj", {}))
        assert.is_nil(m._nearest_sln_dir("D:/repo/Foo/Foo.csproj", nil))
    end)

    it("treats the csproj-at-sln-root case as a match", function()
        local best = m._nearest_sln_dir("D:/repo/Foo.csproj", { "D:/repo" })
        assert.equals("D:/repo", best)
    end)

    it("is case-insensitive on the prefix (Windows path semantics)", function()
        local best = m._nearest_sln_dir(
            "d:\\Repo\\Foo\\Foo.csproj",
            { "D:/repo" }
        )
        assert.equals("D:/repo", best)
    end)
end)

describe("cppcli_user_files workspace_clean dedup + invalidate", function()
    local root

    before_each(function()
        m._reset_for_test()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
    end)

    after_each(function()
        pcall(vim.fn.delete, root, "rf")
    end)

    it("ensure() short-circuits after a clean pass (no vcxproj => instant no-op)", function()
        -- A workspace with no vcxproj should mark itself clean and never
        -- re-scan. We verify by checking that _scan isn't called twice — we
        -- swap it for a counting stub after the first call.
        local first_g, first_s = m.ensure(root)
        assert.equals(0, first_g)
        assert.equals(0, first_s)

        local scan_calls = 0
        local original = m._scan
        m._scan = function(...) scan_calls = scan_calls + 1; return original(...) end
        local g, s = m.ensure(root)
        m._scan = original
        assert.equals(0, g)
        assert.equals(0, s)
        assert.equals(0, scan_calls)
    end)

    it("invalidate(root) reopens the work loop", function()
        m.ensure(root)
        m.invalidate(root)
        local scan_calls = 0
        local original = m._scan
        m._scan = function(...) scan_calls = scan_calls + 1; return original(...) end
        m.ensure(root)
        m._scan = original
        assert.equals(1, scan_calls)
    end)

    it("invalidate() with no args clears all workspaces", function()
        local other = vim.fn.tempname()
        vim.fn.mkdir(other, "p")
        m.ensure(root)
        m.ensure(other)
        m.invalidate()
        local scan_calls = 0
        local original = m._scan
        m._scan = function(...) scan_calls = scan_calls + 1; return original(...) end
        m.ensure(root)
        m.ensure(other)
        m._scan = original
        assert.equals(2, scan_calls)
        pcall(vim.fn.delete, other, "rf")
    end)
end)

describe("cppcli_user_files._all_hint_paths_exist edge cases", function()
    local dir
    local user_path

    before_each(function()
        dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        user_path = dir .. "/Foo.csproj.user"
    end)

    after_each(function()
        pcall(vim.fn.delete, dir, "rf")
    end)

    it("matches <HintPath Condition=...> with attributes (review #1)", function()
        local f = io.open(user_path, "w")
        f:write([[<Project>
  <HintPath Condition="Exists('a.dll')">a.dll</HintPath>
</Project>
]]); f:close()
        -- a.dll missing → should detect the phantom and return false.
        assert.is_false(m._all_hint_paths_exist(user_path, dir))

        local g = io.open(dir .. "/a.dll", "w"); g:write(""); g:close()
        assert.is_true(m._all_hint_paths_exist(user_path, dir))
        pcall(os.remove, dir .. "/a.dll")
    end)

    it("trims surrounding whitespace from the captured HintPath (review #2)", function()
        local g = io.open(dir .. "/a.dll", "w"); g:write(""); g:close()
        local f = io.open(user_path, "w")
        f:write("<Project><HintPath>  a.dll  </HintPath></Project>")
        f:close()
        assert.is_true(m._all_hint_paths_exist(user_path, dir))
        pcall(os.remove, dir .. "/a.dll")
    end)

    it("treats an all-whitespace HintPath as missing", function()
        local f = io.open(user_path, "w")
        f:write("<Project><HintPath>   </HintPath></Project>")
        f:close()
        assert.is_false(m._all_hint_paths_exist(user_path, dir))
    end)
end)

describe("cppcli_user_files.ensure_for_buffer", function()
    local root
    local bufs

    before_each(function()
        m._reset_for_test()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        bufs = {}
    end)

    after_each(function()
        for _, b in ipairs(bufs) do
            pcall(vim.api.nvim_buf_delete, b, { force = true })
        end
        pcall(vim.fn.delete, root, "rf")
    end)

    local function make_buf(name)
        local b = vim.api.nvim_create_buf(false, true)
        if name then vim.api.nvim_buf_set_name(b, name) end
        table.insert(bufs, b)
        return b
    end

    it("returns nil for an unnamed buffer (no work to do)", function()
        local b = make_buf(nil)
        assert.is_nil(m.ensure_for_buffer(b))
    end)

    it("dispatches to ensure with the .sln-rooted workspace", function()
        local f = io.open(root .. "/Top.sln", "w"); f:write(""); f:close()
        vim.fn.mkdir(root .. "/sub", "p")
        local cs_file = root .. "/sub/Foo.cs"
        f = io.open(cs_file, "w"); f:write("// x"); f:close()
        local b = make_buf(cs_file)

        local captured = nil
        local original = m.ensure
        m.ensure = function(r, _) captured = r; return 0, 0 end
        m.ensure_for_buffer(b)
        m.ensure = original

        assert.equals(vim.fs.normalize(root), vim.fs.normalize(captured))
    end)

    it("falls back to .csproj-rooted workspace when no .sln present", function()
        local f = io.open(root .. "/Foo.csproj", "w")
        f:write("<Project/>"); f:close()
        vim.fn.mkdir(root .. "/sub", "p")
        local cs_file = root .. "/sub/Foo.cs"
        f = io.open(cs_file, "w"); f:write("// x"); f:close()
        local b = make_buf(cs_file)

        local captured = nil
        local original = m.ensure
        m.ensure = function(r, _) captured = r; return 0, 0 end
        m.ensure_for_buffer(b)
        m.ensure = original

        assert.equals(vim.fs.normalize(root), vim.fs.normalize(captured))
    end)

    it("silently no-ops for a buffer whose name has no .sln/.csproj ancestor", function()
        -- Use a path inside `root` but with no markers anywhere upward.
        -- (vim.fs.root walks up to drive root; the temp dir has nothing.)
        local cs_file = root .. "/Loose.cs"
        local f = io.open(cs_file, "w"); f:write("// x"); f:close()
        local b = make_buf(cs_file)

        local called = false
        local original = m.ensure
        m.ensure = function(_, _) called = true; return 0, 0 end
        local result = m.ensure_for_buffer(b)
        m.ensure = original

        assert.is_false(called)
        assert.is_nil(result)
    end)
end)

describe("cppcli_user_files ensure() failed-query carve-out", function()
    local root

    before_each(function()
        m._reset_for_test()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
    end)

    after_each(function()
        pcall(vim.fn.delete, root, "rf")
    end)

    local function touch(rel, content)
        local full = root .. "/" .. rel
        vim.fn.mkdir(vim.fs.dirname(full), "p")
        local f = io.open(full, "w"); f:write(content or ""); f:close()
        return full
    end

    it("does NOT mark workspace clean when a vcxproj query returns nil", function()
        touch("Foo/Foo.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Bar\Bar.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("Bar/Bar.vcxproj")

        local query_calls = 0
        local orig_msbuild = m._find_msbuild
        local orig_query = m._query_vcxproj_output
        local orig_notify = vim.notify
        m._find_msbuild = function(_) return "C:\\fake\\MSBuild.exe" end
        m._query_vcxproj_output = function()
            query_calls = query_calls + 1
            return nil
        end
        vim.notify = function(_, _) end -- silence WARN

        m.ensure(root) -- 1st pass: query stubbed to fail
        m.ensure(root) -- 2nd pass: must run the loop again (not short-circuit)

        m._find_msbuild = orig_msbuild
        m._query_vcxproj_output = orig_query
        vim.notify = orig_notify

        -- The 2nd call's loop must have invoked the query stub again.
        -- If workspace_clean had been set, the 2nd ensure() would return
        -- early without entering the loop, leaving query_calls at 1.
        assert.equals(2, query_calls)
    end)

    it("marks clean once all queries succeed", function()
        touch("Foo/Foo.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Bar\Bar.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("Bar/Bar.vcxproj")
        -- Create the DLL the query will point at so HintPath check passes
        -- after the .user gets written.
        touch("Bar/x64/Debug/Bar.dll")

        local query_calls = 0
        local orig_msbuild = m._find_msbuild
        local orig_query = m._query_vcxproj_output
        m._find_msbuild = function(_) return "C:\\fake\\MSBuild.exe" end
        m._query_vcxproj_output = function()
            query_calls = query_calls + 1
            return root .. "\\Bar\\x64\\Debug\\Bar.dll"
        end

        m.ensure(root) -- 1st pass: writes .user, generated=1, NOT marked clean
        m.ensure(root) -- 2nd pass: skips (mtime+HintPath both clean), marks clean
        m.ensure(root) -- 3rd pass: must short-circuit (no query)

        m._find_msbuild = orig_msbuild
        m._query_vcxproj_output = orig_query

        -- 1st call queries the vcxproj. 2nd call skips via _needs_regen
        -- BEFORE the query (HintPath check passes since Bar.dll exists).
        -- 3rd call must short-circuit via workspace_clean.
        assert.equals(1, query_calls)
    end)
end)
