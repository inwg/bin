-- ============================================================
-- MH2c — Workspace Dumper + Animation Collector
-- Saves to C:\matcha\workspace\MH2c\
-- ============================================================

local DUMP_ROOT = "MH2c"
pcall(function() makefolder(DUMP_ROOT) end)

_G._mh2c_anim_ids    = _G._mh2c_anim_ids    or {}
_G._mh2c_anim_counts = _G._mh2c_anim_counts  or {}
_G._mh2c_anim_ignore = _G._mh2c_anim_ignore  or {}
_G._mh2c_anim_backup = _G._mh2c_anim_backup  or {}
_G._mh2c_anim_paused = false
_G._mh2c_anim_start  = os.clock()

-- ============================================================
-- HELPERS
-- ============================================================
local function getCharRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Head")
end

local function findCharacterFolder()
    local names = {"Characters", "Chars", "Players", "NPCs", "Entities", "Mobs"}
    for _, name in ipairs(names) do
        local f = workspace:FindFirstChild(name)
        if f then return f end
    end
    return nil
end

local function cleanAnimID(val)
    if not val or val == "" then return "" end
    return val:match("(%d+)$") or val
end

local function clearTable(t)
    for k in pairs(t) do t[k] = nil end
end

local function getGameName()
    return tostring(game.PlaceId)
end

-- ============================================================
-- UI TAB
-- ============================================================
UI.AddTab("MH2c", function(tab)

    local secL = tab:Section("Dump Options", "Left", {
        "Services",
        "Properties",
        "Filters",
        "Tools",
    }, 400)

    if secL.page == 0 then
        secL:Text("Choose which parts of the game to scan")
        secL:Spacing()
        -- recommended: workspace + replicated + players, skip lighting and serverstorage
        secL:Toggle("dump_workspace",     "Workspace",         true)
        secL:Tip("The main game world — parts, models, NPCs, scripts in the map")
        secL:Toggle("dump_replicated",    "ReplicatedStorage", true)
        secL:Tip("Most important — RemoteEvents and shared game data almost always live here")
        secL:Toggle("dump_players",       "Players",           true)
        secL:Tip("All player instances — stats, characters, leaderstats")
        secL:Toggle("dump_startergui",    "StarterGui",        false)
        secL:Tip("UI templates — turn off to reduce file size significantly, only needed if you care about UI structure")
        secL:Toggle("dump_lighting",      "Lighting",          false)
        secL:Tip("Atmosphere, fog, ambient colour, sky — rarely useful for scripting")
        secL:Toggle("dump_serverstorage", "ServerStorage",     false)
        secL:Tip("Server-only storage — almost always inaccessible from the client")

    elseif secL.page == 1 then
        secL:Text("Choose what details to record for each object")
        secL:Spacing()
        -- recommended: remotes, scripts, values, sounds, animations, attributes — skip everything else
        secL:Toggle("show_remotes",     "RemoteEvents",        true)
        secL:Tip("Network communication points — what you call FireServer on")
        secL:Toggle("show_scripts",     "Scripts",             true)
        secL:Tip("Script names and whether source code is readable or locked")
        secL:Toggle("show_values",      "Value Objects",       true)
        secL:Tip("IntValue, StringValue, BoolValue etc with their current value")
        secL:Toggle("show_sounds",      "Sounds",              true)
        secL:Tip("SoundId, volume and whether currently playing")
        secL:Toggle("show_animations",  "Animations",          true)
        secL:Tip("AnimationId for every Animation object")
        secL:Toggle("show_attributes",  "Attributes",          true)
        secL:Tip("Custom data attached to objects — games often store Moveset, Health, flags etc here")
        secL:Toggle("show_tags",        "Tags",                false)
        secL:Tip("CollectionService tags — minor info, turn on if you specifically need tag data")
        secL:Toggle("show_positions",   "Positions and Sizes", false)
        secL:Tip("Adds two extra lines per part — big impact on file size, only turn on if you need positions")
        secL:Toggle("show_humanoids",   "Character Stats",     true)
        secL:Tip("Health, MaxHealth, WalkSpeed, JumpPower for all characters and NPCs")
        secL:Toggle("show_constraints", "Constraints",         false)
        secL:Tip("WeldConstraints, Motor6Ds etc — rarely needed, adds a lot of noise")
        secL:Toggle("show_lights",      "Lights",              false)
        secL:Tip("Rarely useful for scripting")
        secL:Toggle("show_particles",   "Particles",           false)
        secL:Tip("Games have tons of these — keep off unless you specifically need them")
        secL:Toggle("show_mass",        "Part Mass",           false)
        secL:Tip("Almost never needed")
        secL:Toggle("show_gui_details", "GUI Layout Details",  false)
        secL:Tip("Can cause errors and adds a lot of lines — leave off")

    elseif secL.page == 2 then
        secL:Text("Focus the scan on one specific type of object")
        secL:Text("Pick one or leave all off to scan everything")
        secL:Spacing()
        secL:Toggle("only_remotes",          "RemoteEvents Only",        false)
        secL:Tip("Best starting point for a new game — tiny focused output")
        secL:Toggle("only_humanoids",        "Characters and NPCs Only", false)
        secL:Tip("Only outputs humanoid rigs with their stats")
        secL:Toggle("only_scripts",          "Scripts Only",             false)
        secL:Tip("Maps all code entry points")
        secL:Toggle("only_values",           "Value Objects Only",       false)
        secL:Tip("Find everywhere the game stores player or game state")
        secL:Toggle("only_sounds",           "Sounds Only",              false)
        secL:Tip("Every audio object with SoundIds")
        secL:Toggle("only_animations",       "Animations Only",          false)
        secL:Tip("Every AnimationId — ideal for animation detection tables")
        secL:Toggle("only_attributes",       "Attributes Only",          false)
        secL:Tip("Only objects with custom data — outputs full path and all key-value pairs")
        secL:Toggle("only_bindables",        "Bindables Only",           false)
        secL:Tip("BindableEvent and BindableFunction — internal script communication")
        secL:Toggle("only_models_humanoids", "Character Models Only",    false)
        secL:Tip("Only Model instances that contain a humanoid")

    elseif secL.page == 3 then
        secL:Text("Extra formatting and output tools")
        secL:Spacing()
        secL:Toggle("dump_fullpath",  "Full Instance Paths",   false)
        secL:Tip("Outputs game.Workspace.Folder.Part paths instead of indented tree")
        secL:Toggle("dump_classonly", "Structure Only",        false)
        secL:Tip("Name [ClassName] lines only — clean minimal tree")
        secL:Toggle("dump_timestamp", "Timestamp in Filename", false)
        secL:Tip("Adds a number to the filename so old exports are never overwritten")
        secL:Toggle("dump_separator", "Section Headers",       true)
        secL:Tip("Adds === SERVICE === headers between each scanned service")
        secL:Toggle("dump_linecount", "Line Count Footer",     true)
        secL:Tip("Adds total line count at the bottom of the export")
        secL:Spacing()
        -- recommended: depth 4 — good balance of coverage vs file size
        secL:SliderInt("dump_maxdepth", "Scan Depth (0 = unlimited)", 0, 20, 4)
        secL:Tip("4 is a good balance — catches most useful stuff without scanning every deeply nested object. Set to 0 only when you need everything")
        secL:Spacing()
        secL:Toggle("dump_subfolder",  "Sort by Game Name",     true)
        secL:Tip("Creates a subfolder named after the PlaceId inside MH2c\\")
        secL:InputText("dump_folder",  "Custom Subfolder Name", "")
        secL:Tip("Leave blank to use the PlaceId automatically")
    end

    -- ==================
    -- LEFT: ANIM SETTINGS
    -- ==================
    local secAnim = tab:Section("Anim Settings", "Left", {
        "Watch",
        "Filter",
        "Display",
        "Keybinds",
    }, 400)

    if secAnim.page == 0 then
        secAnim:Toggle("anim_enabled", "AnimVal Watcher", false)
        secAnim:Tip("Watches nearby characters for AnimVal changes — works on games that store animation state in a StringValue called AnimVal on the character")
        secAnim:SliderInt("anim_range", "Watch Range", 10, 500, 60)
        secAnim:Tip("How far away to watch — only applies when target mode uses range")
        secAnim:Toggle("anim_visualize_range", "Visualize Range", false)
        secAnim:Tip("Draws a circle on the ground showing the current watch range")
        secAnim:Spacing()
        secAnim:Combo("anim_target", "Watch Target", {
            "Everyone in Range",
            "Self Only",
            "Specific Player",
            "Player and Self",
            "NPCs Only",
            "Players Only",
            "Everyone"
        }, 0)
        secAnim:Tip("Who to watch for animation changes")
        secAnim:InputText("anim_target_name", "Player Name (Specific Player only)", "")
        secAnim:Tip("Exact username — only used when Watch Target is Specific Player or Player and Self")
        secAnim:Spacing()
        secAnim:Toggle("anim_highlight_watched", "Highlight Watched Players", false)
        secAnim:Tip("Draws a line from screen center to each watched player")
        secAnim:Toggle("anim_esp_labels", "Live AnimVal Labels", false)
        secAnim:Tip("Shows each watched player's current AnimVal above their head in real time")

    elseif secAnim.page == 1 then
        secAnim:Toggle("anim_ignore_empty",      "Ignore Empty Values",        true)
        secAnim:Tip("Skip AnimVal changes where the value is blank — usually means animation ended")
        secAnim:Toggle("anim_new_only",          "Collect New IDs Only",       true)
        secAnim:Tip("Only store IDs not seen before this session")
        secAnim:Toggle("anim_ignore_self_anims", "Ignore Your Own Animations", true)
        secAnim:Tip("Skip animations from your own character")
        secAnim:Toggle("anim_strip_prefix",      "Strip rbxassetid:// Prefix", true)
        secAnim:Tip("Removes the rbxassetid:// part from IDs before storing")
        secAnim:InputText("anim_prefix_filter",  "Only Collect IDs Containing", "")
        secAnim:Tip("Leave blank to collect everything")
        secAnim:Spacing()
        secAnim:Text("Auto-ignore high frequency IDs:")
        secAnim:Toggle("anim_auto_ignore", "Auto-Ignore Spam IDs", true)
        secAnim:Tip("Blacklists any ID that fires more than the threshold — good for filtering walk and idle animations")
        secAnim:SliderInt("anim_auto_ignore_threshold", "Spam Threshold", 2, 50, 10)
        secAnim:Tip("How many times an ID fires before it gets auto-ignored")
        secAnim:Spacing()
        secAnim:SliderInt("anim_min_hits", "Min Hits to Export", 1, 20, 1)
        secAnim:Tip("Only include IDs seen at least this many times when exporting")
        secAnim:Spacing()
        secAnim:InputText("anim_ignore_list", "Ignore List (comma separated IDs)", "")
        secAnim:Tip("Paste IDs you already have here — they wont be collected")

    elseif secAnim.page == 2 then
        secAnim:Toggle("anim_notify",         "Notify on New ID",      true)
        secAnim:Tip("Shows a notification when a brand new ID is seen")
        secAnim:Toggle("anim_print",          "Print All Changes",     false)
        secAnim:Tip("Prints every AnimVal change to output including repeats — off by default to avoid flooding output")
        secAnim:Toggle("anim_print_new_only", "Print New IDs Only",    true)
        secAnim:Tip("Only prints IDs not seen before — cleaner output")
        secAnim:Toggle("anim_print_player",   "Show Player Name",      true)
        secAnim:Tip("Include the player name in output lines")
        secAnim:Toggle("anim_print_prev",     "Show Previous Value",   false)
        secAnim:Tip("Include what the AnimVal was before it changed — off by default to keep output clean")
        secAnim:Toggle("anim_print_hitcount", "Show Hit Count",        false)
        secAnim:Tip("Show how many times each ID has fired")
        secAnim:Toggle("anim_flash_range",    "Flash Range on New ID", false)
        secAnim:Tip("Briefly changes the range circle color when a new ID is detected")
        secAnim:Spacing()
        secAnim:Toggle("anim_save_file", "Auto Save on New ID", false)
        secAnim:Tip("Automatically saves to MH2c/animations.txt every time a new ID is found")

    elseif secAnim.page == 3 then
        secAnim:Text("Watcher control:")
        secAnim:Toggle("anim_enabled_kb_toggle", "Enable Toggle Keybind", false)
        secAnim:Keybind("anim_kb_toggle", 0x70, "toggle")
        secAnim:Tip("Toggle watcher on/off without opening the menu")
        secAnim:Toggle("anim_pause_kb_toggle", "Enable Pause Keybind", false)
        secAnim:Keybind("anim_kb_pause", 0x71, "toggle")
        secAnim:Tip("Pause/resume collection without stopping the watcher")
        secAnim:Spacing()
        secAnim:Text("Output:")
        secAnim:Toggle("anim_copy_kb_toggle", "Enable Copy Keybind", false)
        secAnim:Keybind("anim_kb_copy", 0x72, "toggle")
        secAnim:Tip("Copy collected IDs to clipboard instantly")
        secAnim:Toggle("anim_count_kb_toggle", "Enable Count Keybind", false)
        secAnim:Keybind("anim_kb_count", 0x73, "toggle")
        secAnim:Tip("Print current collected ID count to output")
        secAnim:Toggle("anim_save_kb_toggle", "Enable Save Keybind", false)
        secAnim:Keybind("anim_kb_save", 0x74, "toggle")
        secAnim:Tip("Save to file instantly")
        secAnim:Spacing()
        secAnim:Text("Misc:")
        secAnim:Toggle("anim_clear_kb_toggle", "Enable Clear Keybind", false)
        secAnim:Keybind("anim_kb_clear", 0x75, "toggle")
        secAnim:Tip("Clear collected IDs — saves backup automatically")
        secAnim:Toggle("anim_range_kb_toggle", "Enable Range Visualizer Keybind", false)
        secAnim:Keybind("anim_kb_range", 0x76, "toggle")
        secAnim:Tip("Toggle range circle on/off")
        secAnim:Toggle("anim_esp_kb_toggle", "Enable ESP Labels Keybind", false)
        secAnim:Keybind("anim_kb_esp", 0x77, "toggle")
        secAnim:Tip("Toggle live AnimVal labels on watched players")
        secAnim:Toggle("anim_snapshot_kb_toggle", "Enable Snapshot Keybind", false)
        secAnim:Keybind("anim_kb_snapshot", 0x78, "toggle")
        secAnim:Tip("Manually snapshot the current AnimVal of the nearest player")
    end

    -- ==================
    -- RIGHT: DUMP ACTIONS
    -- ==================
    local secR = tab:Section("Export", "Right")

    secR:InputText("dump_filename", "File Name", "")
    secR:Tip("Leave blank to auto-name from PlaceId")
    secR:Combo("dump_extension", "Extension", {".txt", ".log", ".csv", ".lua", ".json"}, 0)
    secR:Tip(".txt recommended")
    secR:Spacing()
    secR:Button("Save to File",        function() pcall(function() _G._mh2c_run("file")      end) end)
    secR:Button("Copy to Clipboard",   function() pcall(function() _G._mh2c_run("clipboard") end) end)
    secR:Button("Print to Output",     function() pcall(function() _G._mh2c_run("output")    end) end)
    secR:Button("Save + Copy + Print", function() pcall(function() _G._mh2c_run("all")       end) end)
    secR:Spacing()
    secR:Button("Open MH2c Folder", function()
        local ok = pcall(function() os.execute('explorer "C:\\matcha\\workspace\\MH2c"') end)
        if not ok then
            setclipboard("C:\\matcha\\workspace\\MH2c")
            notify("Path copied", "MH2c", 2)
        end
    end)
    secR:Button("Clear Last File", function()
        local extensions = {".txt",".log",".csv",".lua",".json"}
        local ext  = extensions[(UI.GetValue("dump_extension") or 0)+1] or ".txt"
        local name = UI.GetValue("dump_filename") or ""
        local base = (name ~= "") and name or "export"
        pcall(function() writefile(DUMP_ROOT.."/"..base..ext, "") end)
        notify("Cleared "..base..ext, "MH2c", 2)
    end)
    secR:Button("List Saved Files", function()
        local ok, files = pcall(function() return listfiles(DUMP_ROOT) end)
        if ok and files then
            print("[MH2c] Files:")
            for _, f in ipairs(files) do print("  "..tostring(f)) end
            notify("Listed "..#files.." files", "MH2c", 3)
        else
            notify("listfiles not supported", "MH2c", 3)
        end
    end)

    -- ==================
    -- RIGHT: ANIM ACTIONS
    -- ==================
    local secA = tab:Section("Anim Collector", "Right")

    secA:Button("Copy as Lua Table", function()
        local minHits = UI.GetValue("anim_min_hits") or 1
        local lines, count = {}, 0
        for id in pairs(_G._mh2c_anim_ids) do
            if (_G._mh2c_anim_counts[id] or 1) >= minHits then
                count = count + 1
                table.insert(lines, '    ["'..id..'"]=true,')
            end
        end
        if count == 0 then notify("No IDs collected yet", "anim", 2) return end
        setclipboard("local AnimTable = {\n"..table.concat(lines,"\n").."\n}")
        notify("Copied "..count.." IDs as Lua table", "anim", 3)
        print("[ANIM] copied "..count.." IDs")
    end)
    secA:Tip("Paste directly into BlockMode, SkillMode, DashMode etc")

    secA:Button("Copy Raw ID List", function()
        local minHits = UI.GetValue("anim_min_hits") or 1
        local lines, count = {}, 0
        for id in pairs(_G._mh2c_anim_ids) do
            if (_G._mh2c_anim_counts[id] or 1) >= minHits then
                count = count + 1
                table.insert(lines, id)
            end
        end
        if count == 0 then notify("No IDs collected yet", "anim", 2) return end
        setclipboard(table.concat(lines, "\n"))
        notify("Copied "..count.." raw IDs", "anim", 3)
    end)
    secA:Tip("One ID per line")

    secA:Button("Save to File", function()
        local minHits = UI.GetValue("anim_min_hits") or 1
        local lines, count = {}, 0
        for id in pairs(_G._mh2c_anim_ids) do
            if (_G._mh2c_anim_counts[id] or 1) >= minHits then
                count = count + 1
                table.insert(lines, '    ["'..id..'"]=true, -- seen '..(_G._mh2c_anim_counts[id] or 1)..'x')
            end
        end
        if count == 0 then notify("No IDs collected yet", "anim", 2) return end
        local content = "-- MH2c Anim Collector\n-- "..count.." IDs\n\nlocal AnimTable = {\n"..table.concat(lines,"\n").."\n}"
        pcall(function() makefolder(DUMP_ROOT) end)
        local ok = pcall(function() writefile(DUMP_ROOT.."/animations.txt", content) end)
        notify(ok and ("Saved "..count.." IDs") or "Save failed", "anim", 3)
        if ok then print("[ANIM] saved to C:\\matcha\\workspace\\MH2c\\animations.txt") end
    end)

    secA:Button("Load from File", function()
        local ok, content = pcall(function() return readfile(DUMP_ROOT.."/animations.txt") end)
        if not ok or not content then notify("No saved file found", "anim", 2) return end
        local count = 0
        for id in content:gmatch('"(%d+)"') do
            if not _G._mh2c_anim_ids[id] then
                _G._mh2c_anim_ids[id]    = true
                _G._mh2c_anim_counts[id] = _G._mh2c_anim_counts[id] or 1
                count = count + 1
            end
        end
        notify("Loaded "..count.." new IDs", "anim", 3)
        print("[ANIM] loaded "..count.." IDs")
    end)
    secA:Tip("Merges previously saved IDs back in without duplicating")

    secA:Button("Merge Ignore List", function()
        local raw = UI.GetValue("anim_ignore_list") or ""
        local count = 0
        for id in raw:gmatch("[^,]+") do
            local clean = id:match("^%s*(.-)%s*$")
            clean = cleanAnimID(clean)
            if clean ~= "" then
                _G._mh2c_anim_ignore[clean] = true
                _G._mh2c_anim_ids[clean]    = nil
                count = count + 1
            end
        end
        notify("Ignored "..count.." IDs", "anim", 3)
    end)
    secA:Tip("Applies the ignore list — removes and blacklists those IDs")

    secA:Button("Show Stats", function()
        local count, topID, topCount = 0, "", 0
        for id in pairs(_G._mh2c_anim_ids) do
            count = count + 1
            local hits = _G._mh2c_anim_counts[id] or 1
            if hits > topCount then topCount=hits topID=id end
        end
        local elapsed = math.floor(os.clock() - _G._mh2c_anim_start)
        local mins, secs = math.floor(elapsed/60), elapsed%60
        local ignored = 0
        for _ in pairs(_G._mh2c_anim_ignore) do ignored=ignored+1 end
        print("[ANIM] === Stats ===")
        print("[ANIM] Collected: "..count)
        print("[ANIM] Ignored: "..ignored)
        print("[ANIM] Session: "..mins.."m "..secs.."s")
        if topID ~= "" then print("[ANIM] Most seen: "..topID.." ("..topCount.."x)") end
        notify(count.." IDs | "..mins.."m "..secs.."s", "anim", 3)
    end)

    secA:Button("Undo Last Clear", function()
        local count = 0
        for id in pairs(_G._mh2c_anim_backup) do
            if not _G._mh2c_anim_ids[id] then
                _G._mh2c_anim_ids[id] = true
                count = count + 1
            end
        end
        notify("Restored "..count.." IDs", "anim", 3)
    end)

    secA:Button("Clear Collected IDs", function()
        clearTable(_G._mh2c_anim_backup)
        for id in pairs(_G._mh2c_anim_ids) do _G._mh2c_anim_backup[id]=true end
        clearTable(_G._mh2c_anim_ids)
        clearTable(_G._mh2c_anim_counts)
        _G._mh2c_anim_start = os.clock()
        notify("Cleared — Undo Last Clear to restore", "anim", 2)
    end)

end)

-- ============================================================
-- DUMP ENGINE
-- ============================================================
_G._mh2c_run = function(mode)
    local CollectionService = game:GetService("CollectionService")
    local lines = {}

    local maxDepth            = UI.GetValue("dump_maxdepth")          or 4
    local fullPath            = UI.GetValue("dump_fullpath")           or false
    local classOnly           = UI.GetValue("dump_classonly")          or false
    local separator           = UI.GetValue("dump_separator")
    local linecount           = UI.GetValue("dump_linecount")
    local timestamp           = UI.GetValue("dump_timestamp")          or false
    local subfolder           = UI.GetValue("dump_subfolder")
    local folderName          = UI.GetValue("dump_folder")             or ""
    local customName          = UI.GetValue("dump_filename")           or ""
    local extIndex            = UI.GetValue("dump_extension")          or 0
    local onlyRemotes         = UI.GetValue("only_remotes")            or false
    local onlyHumanoids       = UI.GetValue("only_humanoids")          or false
    local onlyScripts         = UI.GetValue("only_scripts")            or false
    local onlyValues          = UI.GetValue("only_values")             or false
    local onlySounds          = UI.GetValue("only_sounds")             or false
    local onlyAnimations      = UI.GetValue("only_animations")         or false
    local onlyAttributes      = UI.GetValue("only_attributes")         or false
    local onlyBindables       = UI.GetValue("only_bindables")          or false
    local onlyModelsHumanoids = UI.GetValue("only_models_humanoids")   or false
    local showRemotes         = UI.GetValue("show_remotes")            or false
    local showScripts         = UI.GetValue("show_scripts")            or false
    local showValues          = UI.GetValue("show_values")             or false
    local showSounds          = UI.GetValue("show_sounds")             or false
    local showAnimations      = UI.GetValue("show_animations")         or false
    local showAttributes      = UI.GetValue("show_attributes")         or false
    local showTags            = UI.GetValue("show_tags")               or false
    local showPositions       = UI.GetValue("show_positions")          or false
    local showHumanoids       = UI.GetValue("show_humanoids")          or false
    local showConstraints     = UI.GetValue("show_constraints")        or false
    local showLights          = UI.GetValue("show_lights")             or false
    local showParticles       = UI.GetValue("show_particles")          or false
    local showMass            = UI.GetValue("show_mass")               or false
    local showGuiDetails      = UI.GetValue("show_gui_details")        or false

    if separator == nil then separator = true end
    if linecount == nil then linecount = true end
    if subfolder == nil then subfolder = true end

    local VALUE_CLASSES = {
        StringValue=true,NumberValue=true,BoolValue=true,IntValue=true,
        Vector3Value=true,CFrameValue=true,ObjectValue=true,Color3Value=true,RayValue=true,
    }
    local CONSTRAINT_CLASSES = {
        WeldConstraint=true,Motor6D=true,BallSocketConstraint=true,HingeConstraint=true,
        RodConstraint=true,RopeConstraint=true,SpringConstraint=true,AlignPosition=true,
        AlignOrientation=true,VectorForce=true,LinearVelocity=true,AngularVelocity=true,
    }
    local LIGHT_CLASSES    = {PointLight=true,SpotLight=true,SurfaceLight=true}
    local PARTICLE_CLASSES = {ParticleEmitter=true,Trail=true,Beam=true}

    local function vec3str(v)
        if not v then return "nil" end
        local ok, r = pcall(function() return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end)
        return ok and r or "nil"
    end

    local function passesFilter(cn)
        if onlyRemotes          then return cn=="RemoteEvent" or cn=="RemoteFunction" or cn=="BindableEvent" or cn=="BindableFunction" end
        if onlyHumanoids        then return cn=="Humanoid" end
        if onlyScripts          then return cn=="Script" or cn=="LocalScript" or cn=="ModuleScript" end
        if onlyValues           then return VALUE_CLASSES[cn]==true end
        if onlySounds           then return cn=="Sound" end
        if onlyAnimations       then return cn=="Animation" end
        if onlyBindables        then return cn=="BindableEvent" or cn=="BindableFunction" end
        if onlyAttributes       then return false end
        return true
    end

    local function listDescendants(instance, indent)
        if not instance then return end
        if maxDepth > 0 and indent > maxDepth then return end

        local okCN, cn   = pcall(function() return instance.ClassName end)
        local okN,  name = pcall(function() return instance.Name end)
        if not okCN or not cn   then return end
        if not okN  or not name then return end

        if onlyModelsHumanoids then
            if cn ~= "Model" then
                local ok, children = pcall(function() return instance:GetChildren() end)
                if ok and children then
                    for _, child in ipairs(children) do listDescendants(child, indent+1) end
                end
                return
            end
            local ok, found = pcall(function() return instance:FindFirstChildOfClass("Humanoid") ~= nil end)
            if not (ok and found) then
                local ok2, children = pcall(function() return instance:GetChildren() end)
                if ok2 and children then
                    for _, child in ipairs(children) do listDescendants(child, indent+1) end
                end
                return
            end
        end

        local prefix = string.rep("  ", indent)
        local displayName
        if fullPath then
            local ok, fp = pcall(function() return instance:GetFullName() end)
            displayName = (ok and fp) or name
        else
            displayName = name
        end

        local line   = (fullPath and "" or prefix)..displayName.." ["..cn.."]"
        local extras = {}

        if not classOnly then
            if showValues and VALUE_CLASSES[cn] then
                local ok, v = pcall(function() return tostring(instance.Value) end)
                if ok and v then line=line.." = "..v end
            end
            if showSounds and cn=="Sound" then
                local ok,id       = pcall(function() return instance.SoundId end)
                local ok2,vol     = pcall(function() return instance.Volume end)
                local ok3,playing = pcall(function() return instance.IsPlaying end)
                if ok and id and id~="" then line=line.." SoundId:"..id end
                if ok2 and vol then line=line.." vol:"..string.format("%.1f",vol) end
                if ok3 and playing then line=line.." [PLAYING]" end
            end
            if showAnimations and cn=="Animation" then
                local ok,id = pcall(function() return instance.AnimationId end)
                if ok and id and id~="" then line=line.." AnimId:"..id end
            end
            if showScripts and (cn=="Script" or cn=="LocalScript" or cn=="ModuleScript") then
                local ok,src = pcall(function() return instance.Source end)
                line=line..(ok and src and (" source:"..#src.." chars") or " source:protected")
            end
            if showRemotes then
                if cn=="RemoteEvent" or cn=="RemoteFunction" then
                    line=line.." <<REMOTE>>"
                elseif cn=="BindableEvent" or cn=="BindableFunction" then
                    line=line.." <<BINDABLE>>"
                end
            end
            if showConstraints and CONSTRAINT_CLASSES[cn] then line=line.." <<CONSTRAINT>>" end
            if showLights and LIGHT_CLASSES[cn] then
                local ok,b = pcall(function() return instance.Brightness end)
                if ok and b then line=line.." brightness:"..string.format("%.1f",b) end
            end
            if showParticles and PARTICLE_CLASSES[cn] then line=line.." <<PARTICLE>>" end
            if showHumanoids and cn=="Humanoid" then
                local okH,hp  = pcall(function() return instance.Health end)
                local okM,mhp = pcall(function() return instance.MaxHealth end)
                local okW,ws  = pcall(function() return instance.WalkSpeed end)
                local okJ,jp  = pcall(function() return instance.JumpPower end)
                if okH and okM and hp and mhp then table.insert(extras, prefix.."  hp: "..string.format("%.1f/%.1f",hp,mhp)) end
                if okW and ws then table.insert(extras, prefix.."  walkspeed: "..tostring(ws)) end
                if okJ and jp then table.insert(extras, prefix.."  jumppower: "..tostring(jp)) end
            end
            if showPositions then
                local ok,isBase = pcall(function() return instance:IsA("BasePart") end)
                if ok and isBase==true then
                    local okP,pos  = pcall(function() return instance.Position end)
                    local okS,size = pcall(function() return instance.Size end)
                    if okP and pos  then table.insert(extras, prefix.."  pos: "..vec3str(pos)) end
                    if okS and size then table.insert(extras, prefix.."  size: "..vec3str(size)) end
                    if showMass then
                        local okMs,mass = pcall(function() return instance:GetMass() end)
                        if okMs and mass then table.insert(extras, prefix.."  mass: "..string.format("%.2f",mass)) end
                    end
                end
            end
            if showAttributes then
                local ok,attrs = pcall(function() return instance:GetAttributes() end)
                if ok and attrs then
                    for k,v in pairs(attrs) do
                        if onlyAttributes then
                            local okFP,fp = pcall(function() return instance:GetFullName() end)
                            table.insert(lines, (okFP and fp or name).." @"..tostring(k).." = "..tostring(v))
                        else
                            table.insert(extras, prefix.."  @"..tostring(k).." = "..tostring(v))
                        end
                    end
                end
            end
            if showTags then
                local ok,tags = pcall(function() return CollectionService:GetTags(instance) end)
                if ok and tags and #tags>0 then
                    table.insert(extras, prefix.."  tags: "..table.concat(tags,", "))
                end
            end
            if showGuiDetails then
                local ok,isGui = pcall(function() return instance:IsA("GuiObject") end)
                if ok and isGui==true then
                    local ok2,vis = pcall(function() return instance.Visible end)
                    local ok3,pos = pcall(function() return instance.AbsolutePosition end)
                    local ok4,sz  = pcall(function() return instance.AbsoluteSize end)
                    if ok2 then line=line..(vis and " [visible]" or " [hidden]") end
                    if ok3 and pos then table.insert(extras, prefix.."  screenPos: ("..string.format("%.0f, %.0f",pos.X,pos.Y)..")") end
                    if ok4 and sz  then table.insert(extras, prefix.."  screenSize: ("..string.format("%.0f, %.0f",sz.X,sz.Y)..")") end
                end
            end
        end

        if passesFilter(cn) then
            table.insert(lines, line)
            for _,extra in ipairs(extras) do table.insert(lines, extra) end
        end

        local ok,children = pcall(function() return instance:GetChildren() end)
        if ok and children then
            for _,child in ipairs(children) do listDescendants(child, indent+1) end
        end
    end

    local function scanService(serviceName, label)
        local ok,svc = pcall(function() return game:GetService(serviceName) end)
        if separator then
            table.insert(lines, "")
            table.insert(lines, "=== "..label.." ===")
        end
        if ok and svc then
            listDescendants(svc, 0)
        else
            table.insert(lines, "(inaccessible)")
        end
    end

    if UI.GetValue("dump_workspace")     then scanService("Workspace",         "WORKSPACE")          end
    if UI.GetValue("dump_replicated")    then scanService("ReplicatedStorage", "REPLICATED STORAGE") end
    if UI.GetValue("dump_players")       then scanService("Players",           "PLAYERS")            end
    if UI.GetValue("dump_startergui")    then scanService("StarterGui",        "STARTER GUI")        end
    if UI.GetValue("dump_lighting")      then scanService("Lighting",          "LIGHTING")           end
    if UI.GetValue("dump_serverstorage") then scanService("ServerStorage",     "SERVER STORAGE")     end

    if linecount then
        table.insert(lines, "")
        table.insert(lines, "=== TOTAL LINES: "..#lines.." ===")
    end

    local extensions = {".txt",".log",".csv",".lua",".json"}
    local ext        = extensions[extIndex+1] or ".txt"
    local baseName   = (customName ~= "") and customName or ("export-"..getGameName())

    if timestamp then
        baseName = baseName.."_"..tostring(math.floor(os.clock()*1000))
    end

    local filename
    if subfolder then
        if folderName == "" then folderName = getGameName() end
        local subPath = DUMP_ROOT.."/"..folderName
        pcall(function() makefolder(subPath) end)
        filename = subPath.."/"..baseName..ext
    else
        filename = DUMP_ROOT.."/"..baseName..ext
    end

    local content = table.concat(lines, "\n")
    print("[MH2c] "..#lines.." lines built, saving to: "..filename)

    if mode=="file" or mode=="all" then
        local okW, writeErr = pcall(function() writefile(filename, content) end)
        if okW then
            print("[MH2c] saved to C:\\matcha\\workspace\\"..filename)
            notify("Saved "..#lines.." lines — "..filename, "MH2c", 4)
        else
            print("[MH2c] writefile failed: "..tostring(writeErr))
            notify("Save failed — check output", "MH2c", 3)
        end
    end
    if mode=="clipboard" or mode=="all" then
        setclipboard(content)
        print("[MH2c] copied to clipboard ("..#lines.." lines)")
        notify("Copied "..#lines.." lines to clipboard", "MH2c", 3)
    end
    if mode=="output" or mode=="all" then
        for _,line in ipairs(lines) do print(line) end
        print("[MH2c] done — "..#lines.." lines")
    end
end

-- ============================================================
-- DRAWINGS
-- ============================================================
local RANGE_SEGMENTS = 40
local rangeLines = {}
for i = 1, RANGE_SEGMENTS do
    local l = Drawing.new("Line")
    l.Thickness = 1
    l.Color = Color3.fromRGB(100, 200, 255)
    l.Visible = false
    rangeLines[i] = l
end

local watchLines = {}
local espLabels  = {}

local function getOrCreateWatchLine(key)
    if not watchLines[key] then
        local l = Drawing.new("Line")
        l.Thickness = 1
        l.Color = Color3.fromRGB(255, 200, 50)
        l.Visible = false
        watchLines[key] = l
    end
    return watchLines[key]
end

local function getOrCreateLabel(key)
    if not espLabels[key] then
        local d = Drawing.new("Text")
        d.Font    = Drawing.Fonts.System
        d.Size    = 14
        d.Color   = Color3.fromRGB(255, 220, 100)
        d.Outline = true
        d.Center  = true
        d.Visible = false
        espLabels[key] = d
    end
    return espLabels[key]
end

local rangeFlashTimer = 0

local function drawRangeCircle(center, radius, color)
    local pts = {}
    for i = 1, RANGE_SEGMENTS do
        local a = ((i-1) / RANGE_SEGMENTS) * math.pi * 2
        pts[i] = Vector3.new(
            center.X + math.cos(a) * radius,
            center.Y,
            center.Z + math.sin(a) * radius
        )
    end
    local screenPts = {}
    for i = 1, RANGE_SEGMENTS do
        local ok, sp, on = pcall(WorldToScreen, pts[i])
        if not ok or not on then
            for j = 1, RANGE_SEGMENTS do rangeLines[j].Visible = false end
            return
        end
        screenPts[i] = sp
    end
    for i = 1, RANGE_SEGMENTS do
        local ni = (i % RANGE_SEGMENTS) + 1
        rangeLines[i].From    = screenPts[i]
        rangeLines[i].To      = screenPts[ni]
        rangeLines[i].Color   = color
        rangeLines[i].Visible = true
    end
end

local function getScreenCenter()
    local cam = workspace.CurrentCamera
    if cam then
        local ok, vs = pcall(function() return cam.ViewportSize end)
        if ok and vs then return Vector2.new(vs.X/2, vs.Y/2) end
    end
    return Vector2.new(960, 540)
end

-- ============================================================
-- KEYBIND LOOP
-- ============================================================
task.spawn(function()
    local Players = game:GetService("Players")
    local lastCopy,lastCount,lastSave,lastClear,lastSnap = false,false,false,false,false

    while true do
        task.wait(0.05)

        if UI.GetValue("anim_enabled_kb_toggle") and UI.GetValue("anim_kb_toggle") then
            UI.SetValue("anim_enabled", not UI.GetValue("anim_enabled"))
            task.wait(0.3)
        end

        if UI.GetValue("anim_pause_kb_toggle") and UI.GetValue("anim_kb_pause") then
            _G._mh2c_anim_paused = not _G._mh2c_anim_paused
            notify(_G._mh2c_anim_paused and "Paused" or "Resumed", "anim", 2)
            task.wait(0.3)
        end

        if UI.GetValue("anim_copy_kb_toggle") then
            local pressed = UI.GetValue("anim_kb_copy")
            if pressed and not lastCopy then
                local lines, count = {}, 0
                local minHits = UI.GetValue("anim_min_hits") or 1
                for id in pairs(_G._mh2c_anim_ids) do
                    if (_G._mh2c_anim_counts[id] or 1) >= minHits then
                        count=count+1
                        table.insert(lines, '    ["'..id..'"]=true,')
                    end
                end
                if count>0 then
                    setclipboard("local AnimTable = {\n"..table.concat(lines,"\n").."\n}")
                    notify("Copied "..count.." IDs", "anim", 2)
                else notify("Nothing to copy", "anim", 2) end
            end
            lastCopy = pressed
        end

        if UI.GetValue("anim_count_kb_toggle") then
            local pressed = UI.GetValue("anim_kb_count")
            if pressed and not lastCount then
                local count = 0
                for _ in pairs(_G._mh2c_anim_ids) do count=count+1 end
                notify(count.." IDs collected", "anim", 2)
                print("[ANIM] "..count.." IDs")
            end
            lastCount = pressed
        end

        if UI.GetValue("anim_save_kb_toggle") then
            local pressed = UI.GetValue("anim_kb_save")
            if pressed and not lastSave then
                local lines, count = {}, 0
                for id in pairs(_G._mh2c_anim_ids) do
                    count=count+1
                    table.insert(lines, '    ["'..id..'"]=true, -- seen '..(_G._mh2c_anim_counts[id] or 1)..'x')
                end
                if count>0 then
                    pcall(function() makefolder(DUMP_ROOT) end)
                    pcall(function() writefile(DUMP_ROOT.."/animations.txt",
                        "local AnimTable = {\n"..table.concat(lines,"\n").."\n}") end)
                    notify("Saved "..count.." IDs", "anim", 2)
                else notify("Nothing to save", "anim", 2) end
            end
            lastSave = pressed
        end

        if UI.GetValue("anim_clear_kb_toggle") then
            local pressed = UI.GetValue("anim_kb_clear")
            if pressed and not lastClear then
                clearTable(_G._mh2c_anim_backup)
                for id in pairs(_G._mh2c_anim_ids) do _G._mh2c_anim_backup[id]=true end
                clearTable(_G._mh2c_anim_ids)
                clearTable(_G._mh2c_anim_counts)
                _G._mh2c_anim_start = os.clock()
                notify("Cleared", "anim", 2)
            end
            lastClear = pressed
        end

        if UI.GetValue("anim_range_kb_toggle") and UI.GetValue("anim_kb_range") then
            UI.SetValue("anim_visualize_range", not UI.GetValue("anim_visualize_range"))
            task.wait(0.3)
        end

        if UI.GetValue("anim_esp_kb_toggle") and UI.GetValue("anim_kb_esp") then
            UI.SetValue("anim_esp_labels", not UI.GetValue("anim_esp_labels"))
            task.wait(0.3)
        end

        if UI.GetValue("anim_snapshot_kb_toggle") then
            local pressed = UI.GetValue("anim_kb_snapshot")
            if pressed and not lastSnap then
                local LocalPlayer = Players.LocalPlayer
                local myChar = LocalPlayer and LocalPlayer.Character
                local myHRP  = getCharRoot(myChar)
                if myHRP then
                    local nearest, nearestDist = nil, math.huge
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p==LocalPlayer then continue end
                        local hrp = getCharRoot(p.Character)
                        if hrp then
                            local d = hrp.Position - myHRP.Position
                            local dist = d.X*d.X + d.Y*d.Y + d.Z*d.Z
                            if dist < nearestDist then nearestDist=dist nearest=p.Character end
                        end
                    end
                    if nearest then
                        local animVal = nearest:FindFirstChild("AnimVal")
                        if animVal then
                            local ok,val = pcall(function() return animVal.Value end)
                            if ok and val and val~="" then
                                local id = (UI.GetValue("anim_strip_prefix") or false) and cleanAnimID(val) or val
                                if not _G._mh2c_anim_ids[id] then
                                    _G._mh2c_anim_ids[id]    = true
                                    _G._mh2c_anim_counts[id] = 1
                                    notify("Snapshot: "..id, "anim", 3)
                                    print("[ANIM] snapshot: "..id)
                                else notify("Already have: "..id, "anim", 2) end
                            else notify("No AnimVal on nearest player", "anim", 2) end
                        else notify("Nearest player has no AnimVal", "anim", 2) end
                    else notify("No nearby players", "anim", 2) end
                end
            end
            lastSnap = pressed
        end
    end
end)

-- ============================================================
-- MAIN ANIM WATCHER LOOP
-- ============================================================
task.spawn(function()
    local Players    = game:GetService("Players")
    local lastValues = {}

    while true do
        task.wait(0.05)

        for i = 1, RANGE_SEGMENTS do rangeLines[i].Visible = false end
        for _,l in pairs(watchLines) do l.Visible = false end
        for _,l in pairs(espLabels)  do l.Visible = false end

        if not UI.GetValue("anim_enabled") then continue end
        if _G._mh2c_anim_paused then continue end

        local LocalPlayer = Players.LocalPlayer
        local myChar = LocalPlayer and LocalPlayer.Character
        local myHRP  = getCharRoot(myChar)
        if not myHRP then continue end

        local range        = UI.GetValue("anim_range")                 or 60
        local targetMode   = UI.GetValue("anim_target")                or 0
        local targetName   = UI.GetValue("anim_target_name")           or ""
        local prefixFilter = UI.GetValue("anim_prefix_filter")         or ""
        local autoIgnore   = UI.GetValue("anim_auto_ignore")           or false
        local autoThresh   = UI.GetValue("anim_auto_ignore_threshold") or 10
        local stripPrefix  = UI.GetValue("anim_strip_prefix")          or false

        if UI.GetValue("anim_visualize_range") then
            local flashColor = (rangeFlashTimer > os.clock()) and
                Color3.fromRGB(255, 100, 50) or
                Color3.fromRGB(100, 200, 255)
            drawRangeCircle(myHRP.Position, range, flashColor)
        end

        local targets = {}
        local playerNames = {}
        for _,p in ipairs(Players:GetPlayers()) do playerNames[p.Name]=true end

        local function addPlayer(p, isSelf)
            if not p.Character then return end
            table.insert(targets, {char=p.Character, name=p.Name, isNPC=false, isSelf=isSelf})
        end

        local function addNPCs()
            local chars = findCharacterFolder()
            if not chars then
                for _,model in ipairs(workspace:GetChildren()) do
                    if model.ClassName=="Model" and not playerNames[model.Name] then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        if hum then
                            table.insert(targets, {char=model, name=model.Name, isNPC=true, isSelf=false})
                        end
                    end
                end
                return
            end
            for _,model in ipairs(chars:GetChildren()) do
                if not playerNames[model.Name] then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hum then
                        table.insert(targets, {char=model, name=model.Name, isNPC=true, isSelf=false})
                    end
                end
            end
        end

        local function inRange(char)
            local hrp = getCharRoot(char)
            if not hrp then return false end
            local d = hrp.Position - myHRP.Position
            return (d.X*d.X + d.Y*d.Y + d.Z*d.Z) <= (range*range)
        end

        if     targetMode==1 then addPlayer(LocalPlayer, true)
        elseif targetMode==2 then
            for _,p in ipairs(Players:GetPlayers()) do
                if p.Name==targetName then addPlayer(p, false) end
            end
        elseif targetMode==3 then
            addPlayer(LocalPlayer, true)
            for _,p in ipairs(Players:GetPlayers()) do
                if p.Name==targetName then addPlayer(p, false) end
            end
        elseif targetMode==4 then addNPCs()
        elseif targetMode==5 then
            for _,p in ipairs(Players:GetPlayers()) do
                if p==LocalPlayer and UI.GetValue("anim_ignore_self_anims") then continue end
                if inRange(p.Character) then addPlayer(p, p==LocalPlayer) end
            end
        elseif targetMode==6 then
            for _,p in ipairs(Players:GetPlayers()) do
                if p==LocalPlayer and UI.GetValue("anim_ignore_self_anims") then continue end
                addPlayer(p, p==LocalPlayer)
            end
            addNPCs()
        else
            for _,p in ipairs(Players:GetPlayers()) do
                if p==LocalPlayer and UI.GetValue("anim_ignore_self_anims") then continue end
                if inRange(p.Character) then addPlayer(p, p==LocalPlayer) end
            end
        end

        local screenCenter = getScreenCenter()

        for _,target in ipairs(targets) do
            local hrp = getCharRoot(target.char)

            if hrp and UI.GetValue("anim_highlight_watched") then
                local ok,sp,on = pcall(WorldToScreen, hrp.Position)
                if ok and on then
                    local wl = getOrCreateWatchLine(target.name)
                    wl.From    = screenCenter
                    wl.To      = sp
                    wl.Visible = true
                end
            end

            if hrp and UI.GetValue("anim_esp_labels") then
                local ok,sp,on = pcall(WorldToScreen, hrp.Position + Vector3.new(0,3,0))
                if ok and on then
                    local lbl = getOrCreateLabel(target.name)
                    lbl.Text     = target.name..": "..(lastValues[target.name] or "")
                    lbl.Position = sp
                    lbl.Visible  = true
                end
            end

            local animVal = target.char:FindFirstChild("AnimVal")
            if not animVal then continue end
            local ok,val = pcall(function() return animVal.Value end)
            if not ok or type(val)~="string" then continue end
            if (UI.GetValue("anim_ignore_empty") or false) and val=="" then continue end

            local id = stripPrefix and cleanAnimID(val) or val
            if id == "" then continue end
            if _G._mh2c_anim_ignore[id] then continue end
            if prefixFilter~="" and not id:find(prefixFilter,1,true) then continue end

            local last = lastValues[target.name]
            if val==last then continue end
            lastValues[target.name] = val

            _G._mh2c_anim_counts[id] = (_G._mh2c_anim_counts[id] or 0) + 1

            if autoIgnore and (_G._mh2c_anim_counts[id] or 0) >= autoThresh then
                _G._mh2c_anim_ignore[id] = true
                _G._mh2c_anim_ids[id]    = nil
                print("[ANIM] auto-ignored: "..id)
                continue
            end

            local isNew = not _G._mh2c_anim_ids[id]
            local shouldPrint = (UI.GetValue("anim_print") or false) or
                               ((UI.GetValue("anim_print_new_only") or false) and isNew)

            if shouldPrint then
                local parts = {}
                if UI.GetValue("anim_print_player") or false then
                    table.insert(parts, target.name..(target.isNPC and " [NPC]" or ""))
                end
                table.insert(parts, id)
                if UI.GetValue("anim_print_prev") or false then
                    local lastClean = last and (stripPrefix and cleanAnimID(last) or last) or "nil"
                    table.insert(parts, "(was: "..lastClean..")")
                end
                if UI.GetValue("anim_print_hitcount") or false then
                    table.insert(parts, "hits:"..tostring(_G._mh2c_anim_counts[id]))
                end
                print("[ANIM] "..table.concat(parts, "  "))
            end

            if isNew then
                _G._mh2c_anim_ids[id] = true
                if UI.GetValue("anim_notify") or false then notify("New ID: "..id, "anim", 3) end
                if UI.GetValue("anim_flash_range") or false then rangeFlashTimer = os.clock() + 0.5 end
                if UI.GetValue("anim_save_file") or false then
                    local saveLines = {}
                    for sid in pairs(_G._mh2c_anim_ids) do
                        table.insert(saveLines, '    ["'..sid..'"]=true, -- seen '..(_G._mh2c_anim_counts[sid] or 1)..'x')
                    end
                    pcall(function() makefolder(DUMP_ROOT) end)
                    pcall(function() writefile(DUMP_ROOT.."/animations.txt",
                        "local AnimTable = {\n"..table.concat(saveLines,"\n").."\n}") end)
                end
            end
        end
    end
end)

notify("MH2c loaded", "MH2c", 2)
