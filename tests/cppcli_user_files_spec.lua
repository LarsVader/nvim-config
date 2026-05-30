-- Tests for lars.cppcli_user_files — the .user generator that lets Roslyn
-- LSP resolve types from C++/CLI assemblies referenced via vcxproj
-- ProjectReferences.

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

    it("ignores commented-out ProjectReferences and References", function()
        local xml = [[
<Project>
  <!-- <ProjectReference Include="..\Stub\Stub.vcxproj" /> -->
  <!-- <Reference Include="OldName" /> -->
  <ProjectReference Include="..\Real\Real.vcxproj" />
  <Reference Include="ActiveName" />
</Project>
]]
        local r = m._parse_csproj(xml)
        assert.same({ "..\\Real\\Real.vcxproj" }, r.vcxproj_refs)
        assert.is_nil(r.existing_refs["OldName"])
        assert.is_true(r.existing_refs["ActiveName"])
    end)

    it("captures csproj ProjectReferences separately from vcxproj refs", function()
        local xml = [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Sibling\Sibling.csproj" />
    <ProjectReference Include="..\Native\Foo.vcxproj" />
  </ItemGroup>
</Project>
]]
        local r = m._parse_csproj(xml)
        assert.same({ "..\\Native\\Foo.vcxproj" }, r.vcxproj_refs)
        assert.same({ "..\\Sibling\\Sibling.csproj" }, r.csproj_refs)
    end)
end)

describe("cppcli_user_files._gather_transitive_vcxprojs", function()
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

    it("returns direct vcxproj refs of the csproj", function()
        local cs = touch("A/A.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\X\X.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("X/X.vcxproj")
        local result = m._gather_transitive_vcxprojs(cs)
        assert.equals(1, #result)
        assert.equals(
            vim.fs.normalize(root .. "/X/X.vcxproj"),
            vim.fs.normalize(result[1]))
    end)

    it("follows csproj -> csproj -> vcxproj chains", function()
        local a = touch("A/A.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\B\B.csproj" />
  </ItemGroup>
</Project>
]])
        touch("B/B.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\X\X.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("X/X.vcxproj")
        local result = m._gather_transitive_vcxprojs(a)
        assert.equals(1, #result)
        assert.is_truthy(vim.fs.normalize(result[1]):match("/X/X%.vcxproj$"))
    end)

    it("combines direct and transitive vcxproj refs", function()
        local a = touch("A/A.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Direct\Direct.vcxproj" />
    <ProjectReference Include="..\B\B.csproj" />
  </ItemGroup>
</Project>
]])
        touch("Direct/Direct.vcxproj")
        touch("B/B.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Transitive\Transitive.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("Transitive/Transitive.vcxproj")
        local result = m._gather_transitive_vcxprojs(a)
        assert.equals(2, #result)
    end)

    it("dedupes when the same vcxproj is reached through multiple paths", function()
        local a = touch("A/A.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\B\B.csproj" />
    <ProjectReference Include="..\C\C.csproj" />
  </ItemGroup>
</Project>
]])
        touch("B/B.csproj", [[
<Project><ItemGroup><ProjectReference Include="..\Shared\Shared.vcxproj" /></ItemGroup></Project>
]])
        touch("C/C.csproj", [[
<Project><ItemGroup><ProjectReference Include="..\Shared\Shared.vcxproj" /></ItemGroup></Project>
]])
        touch("Shared/Shared.vcxproj")
        local result = m._gather_transitive_vcxprojs(a)
        assert.equals(1, #result)
    end)

    it("does not infinite-loop on a csproj cycle", function()
        local a = touch("A/A.csproj", [[
<Project><ItemGroup><ProjectReference Include="..\B\B.csproj" /></ItemGroup></Project>
]])
        touch("B/B.csproj", [[
<Project><ItemGroup><ProjectReference Include="..\A\A.csproj" /></ItemGroup></Project>
]])
        local result = m._gather_transitive_vcxprojs(a)
        assert.same({}, result)
    end)

    it("returns empty when the csproj has no refs at all", function()
        local cs = touch("A/A.csproj", "<Project/>")
        assert.same({}, m._gather_transitive_vcxprojs(cs))
    end)

    it("silently ignores a <ProjectReference> to a csproj that's missing on disk", function()
        local a = touch("A/A.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Gone\Gone.csproj" />
    <ProjectReference Include="..\X\X.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("X/X.vcxproj")
        -- Gone.csproj never created; should just be skipped.
        local result = m._gather_transitive_vcxprojs(a)
        assert.equals(1, #result)
        assert.is_truthy(vim.fs.normalize(result[1]):match("/X/X%.vcxproj$"))
    end)

    it("follows a relative csproj ref that resolves outside workspace_root", function()
        -- The walk doesn't restrict to workspace_root. A relative ref
        -- that climbs out gets read normally; downstream lookups will
        -- silently no-op if the resulting vcxproj's DLL isn't indexed.
        local outside = root .. "/../Outside"
        vim.fn.mkdir(outside, "p")
        touch("Inside/A.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\..\Outside\Out.csproj" />
  </ItemGroup>
</Project>
]])
        local out_cs = outside .. "/Out.csproj"
        local f = io.open(out_cs, "w")
        f:write([[<Project><ItemGroup><ProjectReference Include=".\Bar.vcxproj" /></ItemGroup></Project>]])
        f:close()
        local fb = io.open(outside .. "/Bar.vcxproj", "w"); fb:write(""); fb:close()
        local result = m._gather_transitive_vcxprojs(root .. "/Inside/A.csproj")
        assert.equals(1, #result)
        assert.is_truthy(vim.fs.normalize(result[1]):match("/Bar%.vcxproj$"))
        pcall(vim.fn.delete, outside, "rf")
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

    it("walks up multiple levels to reach a sibling subtree", function()
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

    it("collects csprojs, vcxprojs, and DLL index entries", function()
        touch("Foo/Foo.csproj")
        touch("Bar/Bar.vcxproj")
        touch("Bar/x64/Debug/Bar.dll")
        local csprojs, vcxprojs, dll_index = m._scan(root)
        assert.equals(1, #csprojs)
        assert.equals(1, #vcxprojs)
        assert.is_table(dll_index["bar"])
        assert.equals(1, #dll_index["bar"])
    end)

    it("indexes DLLs by lowercased basename without extension", function()
        touch("a/MixedCase.DLL")
        touch("b/Mixedcase.dll")
        local _, _, dll_index = m._scan(root)
        -- Both should land in the same `mixedcase` key (case-insensitive).
        assert.is_table(dll_index["mixedcase"])
        assert.equals(2, #dll_index["mixedcase"])
    end)

    it("respects the noise-dir skip list", function()
        touch(".git/Hidden.vcxproj")
        touch("bin/inner/Buried.dll")
        touch("Real/Real.vcxproj")
        touch("Real/Real.dll")
        local _, vcxprojs, dll_index = m._scan(root)
        assert.equals(1, #vcxprojs)
        assert.is_table(dll_index["real"])
        assert.is_nil(dll_index["buried"])
    end)
end)

describe("cppcli_user_files._find_dll_for_assembly", function()
    it("returns nil for an unknown assembly", function()
        assert.is_nil(m._find_dll_for_assembly({}, "Ghost"))
    end)

    it("returns the single candidate when only one DLL matches", function()
        local idx = { cliwrapper = { "D:/repo/out/CliWrapper.dll" } }
        assert.equals("D:/repo/out/CliWrapper.dll",
            m._find_dll_for_assembly(idx, "CliWrapper"))
    end)

    it("prefers a DLL whose path is under hint_dir", function()
        local idx = {
            cliwrapper = {
                "D:/repo/elsewhere/CliWrapper.dll",
                "D:/repo/CliWrapper/bin/CliWrapper.dll",
            },
        }
        assert.equals("D:/repo/CliWrapper/bin/CliWrapper.dll",
            m._find_dll_for_assembly(idx, "CliWrapper", "D:/repo/CliWrapper"))
    end)

    it("falls back to newest mtime when no candidate is under hint_dir", function()
        local tmp = vim.fn.tempname()
        vim.fn.mkdir(tmp, "p")
        local older = tmp .. "/Old.dll"
        local newer = tmp .. "/New.dll"
        local f = io.open(older, "w"); f:write(""); f:close()
        vim.uv.sleep(1100)
        f = io.open(newer, "w"); f:write(""); f:close()
        local idx = { foo = { older, newer } }
        local pick = m._find_dll_for_assembly(idx, "Foo")
        assert.equals(newer, pick)
        pcall(vim.fn.delete, tmp, "rf")
    end)

    it("picks newest among DLLs under hint_dir (within-hint_dir staleness)", function()
        local tmp = vim.fn.tempname()
        vim.fn.mkdir(tmp .. "/MyLib/bin/Debug", "p")
        vim.fn.mkdir(tmp .. "/MyLib/bin/Release", "p")
        local debug = tmp .. "/MyLib/bin/Debug/MyLib.dll"
        local release = tmp .. "/MyLib/bin/Release/MyLib.dll"
        -- Debug first (older), Release second (newer).
        local f = io.open(debug, "w"); f:write(""); f:close()
        vim.uv.sleep(1100)
        f = io.open(release, "w"); f:write(""); f:close()
        -- Index order intentionally Debug-first to expose first-match bug.
        local idx = { mylib = { debug, release } }
        local pick = m._find_dll_for_assembly(idx, "MyLib", tmp .. "/MyLib")
        assert.equals(release, pick)
        pcall(vim.fn.delete, tmp, "rf")
    end)

    it("is case-insensitive on the assembly name", function()
        local idx = { cliwrapper = { "D:/repo/CliWrapper.dll" } }
        assert.equals("D:/repo/CliWrapper.dll",
            m._find_dll_for_assembly(idx, "CLIWRAPPER"))
    end)
end)

describe("cppcli_user_files.find_vcxproj_dir_for_assembly", function()
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

    it("returns the dir of the vcxproj whose filename matches the asm name", function()
        touch("CliWrapper/CliWrapper.vcxproj")
        touch("Other/Other.vcxproj")
        local dir = m.find_vcxproj_dir_for_assembly(root, "CliWrapper")
        assert.equals(vim.fs.normalize(root .. "/CliWrapper"),
            vim.fs.normalize(dir))
    end)

    it("is case-insensitive on the assembly name match", function()
        touch("CliWrapper/CliWrapper.vcxproj")
        local dir = m.find_vcxproj_dir_for_assembly(root, "cliwrapper")
        assert.equals(vim.fs.normalize(root .. "/CliWrapper"),
            vim.fs.normalize(dir))
    end)

    it("returns nil when no vcxproj filename matches the asm name", function()
        touch("Other/Other.vcxproj")
        assert.is_nil(m.find_vcxproj_dir_for_assembly(root, "Nonexistent"))
    end)

    it("caches results across calls", function()
        touch("CliWrapper/CliWrapper.vcxproj")
        local first = m.find_vcxproj_dir_for_assembly(root, "CliWrapper")
        -- Delete the vcxproj; cached call must still return.
        pcall(vim.fn.delete, root .. "/CliWrapper", "rf")
        local second = m.find_vcxproj_dir_for_assembly(root, "CliWrapper")
        assert.equals(first, second)
    end)

    it("invalidate(root) drops the vcxproj_dir cache", function()
        touch("Foo/Foo.vcxproj")
        local first = m.find_vcxproj_dir_for_assembly(root, "Foo")
        assert.is_not_nil(first)
        m.invalidate(root)
        touch("Bar/Bar.vcxproj")
        local second = m.find_vcxproj_dir_for_assembly(root, "Bar")
        assert.is_not_nil(second)
    end)
end)

describe("cppcli_user_files.ensure", function()
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

    it("writes a .user for each csproj with a vcxproj ProjectReference whose DLL exists", function()
        touch("Foo/Foo.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Bar\Bar.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("Bar/Bar.vcxproj")
        touch("x64/Debug/Bar.dll")
        local g, s = m.ensure(root)
        assert.equals(1, g)
        assert.equals(0, s)

        local content = ""
        local f = io.open(root .. "/Foo/Foo.csproj.user", "r")
        assert.is_not_nil(f)
        if f then content = f:read("*a"); f:close() end
        assert.is_truthy(content:find("<Reference Include=\"Bar\">", 1, true))
        assert.is_truthy(content:find("Bar.dll", 1, true))
    end)

    it("does NOT write a .user when no matching DLL is found", function()
        touch("Foo/Foo.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Bar\Bar.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("Bar/Bar.vcxproj")
        -- No Bar.dll anywhere.
        local g, s = m.ensure(root)
        assert.equals(0, g)
        assert.is_nil(vim.uv.fs_stat(root .. "/Foo/Foo.csproj.user"))
    end)

    it("skips vcxprojs the csproj already references via <Reference>", function()
        touch("Foo/Foo.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Bar\Bar.vcxproj">
      <ReferenceOutputAssembly>false</ReferenceOutputAssembly>
    </ProjectReference>
    <Reference Include="Bar"><HintPath>..\x64\Debug\Bar.dll</HintPath></Reference>
  </ItemGroup>
</Project>
]])
        touch("Bar/Bar.vcxproj")
        touch("x64/Debug/Bar.dll")
        local g, _ = m.ensure(root)
        -- No new .user — the csproj already handled Bar manually.
        assert.equals(0, g)
        assert.is_nil(vim.uv.fs_stat(root .. "/Foo/Foo.csproj.user"))
    end)

    it("writes transitive vcxprojs reached through intermediate csprojs", function()
        -- A.csproj -> B.csproj -> Indirect.vcxproj (only chain)
        touch("A/A.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\B\B.csproj" />
  </ItemGroup>
</Project>
]])
        touch("B/B.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Indirect\Indirect.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("Indirect/Indirect.vcxproj")
        touch("x64/Debug/Indirect.dll")
        local g, _ = m.ensure(root)
        -- A.user written with Indirect; B.user written with Indirect too.
        assert.equals(2, g)

        local f = io.open(root .. "/A/A.csproj.user", "r")
        assert.is_not_nil(f)
        local a_content = f:read("*a"); f:close()
        assert.is_truthy(a_content:find("<Reference Include=\"Indirect\">", 1, true))
    end)

    local function slurp(p)
        local f = io.open(p, "r"); if not f then return nil end
        local c = f:read("*a"); f:close(); return c
    end

    it("regenerates when a newer DLL appears (Debug -> Release staleness)", function()
        touch("Foo/Foo.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Bar\Bar.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("Bar/Bar.vcxproj")
        touch("x64/Debug/Bar.dll")
        m.ensure(root)
        local first = slurp(root .. "/Foo/Foo.csproj.user")
        assert.is_truthy(first:find("Debug\\Bar.dll", 1, true))

        -- A newer Release DLL appears (sleep so its mtime is strictly
        -- greater on 1s-granularity filesystems).
        vim.uv.sleep(1100)
        touch("x64/Release/Bar.dll")
        m._reset_for_test() -- drop scan_cache so the new DLL is indexed
        local g, _ = m.ensure(root)
        assert.equals(1, g)
        local second = slurp(root .. "/Foo/Foo.csproj.user")
        assert.is_truthy(second:find("Release\\Bar.dll", 1, true))
        assert.is_nil(second:find("Debug\\Bar.dll", 1, true))
    end)

    it("finds DLLs in a top-level output dir disjoint from the vcxproj's dir", function()
        -- vcxproj sits at src/MyLib/; the DLL is at repo/out/Debug/ — a
        -- sibling tree, not under the vcxproj's parent.
        touch("src/Consumer/Consumer.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\MyLib\MyLib.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("src/MyLib/MyLib.vcxproj")
        local out_dll = touch("out/Debug/MyLib.dll")

        local g, _ = m.ensure(root)
        assert.equals(1, g)
        local content = slurp(root .. "/src/Consumer/Consumer.csproj.user")
        assert.is_truthy(content)
        -- HintPath should resolve to repo/out/Debug/MyLib.dll relative to
        -- the consumer csproj's dir (src/Consumer/).
        assert.is_truthy(content:find("MyLib.dll", 1, true))
        assert.is_truthy(content:find("..\\..\\out\\Debug\\MyLib.dll", 1, true))
        local _unused = out_dll
    end)

    it("removes a stale .user when its vcxprojs no longer have DLLs", function()
        touch("Foo/Foo.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Bar\Bar.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("Bar/Bar.vcxproj")
        touch("x64/Debug/Bar.dll")
        m.ensure(root)
        assert.is_not_nil(vim.uv.fs_stat(root .. "/Foo/Foo.csproj.user"))

        pcall(vim.fn.delete, root .. "/x64", "rf")
        m._reset_for_test()
        m.ensure(root)
        assert.is_nil(vim.uv.fs_stat(root .. "/Foo/Foo.csproj.user"))
    end)

    it("preserves a hand-written .user that lacks the auto-generated marker", function()
        touch("Foo/Foo.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Bar\Bar.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("Bar/Bar.vcxproj")
        touch("x64/Debug/Bar.dll")
        local manual = root .. "/Foo/Foo.csproj.user"
        local f = io.open(manual, "w")
        f:write([[<Project>
  <ItemGroup>
    <Reference Include="Bar"><HintPath>handwritten\path\Bar.dll</HintPath></Reference>
  </ItemGroup>
</Project>
]])
        f:close()
        local before = slurp(manual)
        m.ensure(root)
        local after = slurp(manual)
        assert.equals(before, after)
    end)

    it("skips a csproj whose .user is current (mtime + HintPath check)", function()
        touch("Foo/Foo.csproj", [[
<Project>
  <ItemGroup>
    <ProjectReference Include="..\Bar\Bar.vcxproj" />
  </ItemGroup>
</Project>
]])
        touch("Bar/Bar.vcxproj")
        touch("x64/Debug/Bar.dll")
        m.ensure(root)
        -- Drop scan cache so the second pass re-walks (mimics a refresh).
        m._reset_for_test()
        local g, s = m.ensure(root)
        assert.equals(0, g)
        assert.equals(1, s)
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

    local function touch(rel, content)
        local full = root .. "/" .. rel
        vim.fn.mkdir(vim.fs.dirname(full), "p")
        local f = io.open(full, "w"); f:write(content or ""); f:close()
        return full
    end

    it("schedules ensure() asynchronously and runs at most once per session per workspace", function()
        touch("Top.sln")
        touch("Foo/Foo.csproj", [[
<Project><ItemGroup><ProjectReference Include="..\Bar\Bar.vcxproj" /></ItemGroup></Project>
]])
        touch("Bar/Bar.vcxproj")
        touch("x64/Debug/Bar.dll")
        local cs = root .. "/Foo/Foo.cs"
        local f = io.open(cs, "w"); f:write("// x"); f:close()
        local b = make_buf(cs)

        m.ensure_for_buffer(b)
        m.ensure_for_buffer(b) -- second call should be a no-op (attempted flag set)

        -- Let the scheduled work complete.
        vim.wait(2000, function()
            return vim.uv.fs_stat(root .. "/Foo/Foo.csproj.user") ~= nil
        end)
        assert.is_not_nil(vim.uv.fs_stat(root .. "/Foo/Foo.csproj.user"))
    end)

    it("returns silently when the buffer has no associated file", function()
        local b = make_buf(nil)
        assert.has_no_error(function() m.ensure_for_buffer(b) end)
    end)

    it("returns silently when no .sln/.csproj ancestor exists", function()
        -- A loose .cs file with nothing upstream. Behavior: no-op, no error.
        local cs = root .. "/Loose.cs"
        local f = io.open(cs, "w"); f:write("// x"); f:close()
        local b = make_buf(cs)
        assert.has_no_error(function() m.ensure_for_buffer(b) end)
    end)
end)
