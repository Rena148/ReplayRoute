--[[
    ReplayRoute 2.0.1 - OBS Replay Buffer clip organizer for Windows.
    Native Win32 calls through LuaJIT FFI; no external shell processes.
]]

local obs = obslua
local ffi = require("ffi")

-- Native Win32 declarations.
ffi.cdef[[
    typedef void* HWND;
    typedef void* HANDLE;
    typedef unsigned long DWORD;
    typedef int BOOL;
    typedef const wchar_t* LPCWSTR;
    typedef wchar_t* LPWSTR;
    typedef const char* LPCSTR;
    typedef char* LPSTR;
    typedef uintptr_t ULONG_PTR;

    HWND GetForegroundWindow(void);
    DWORD GetWindowThreadProcessId(HWND hWnd, DWORD* lpdwProcessId);
    HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
    BOOL QueryFullProcessImageNameW(HANDLE hProcess, DWORD dwFlags, LPWSTR lpExeName, DWORD* lpdwSize);
    BOOL CloseHandle(HANDLE hObject);

    BOOL CreateDirectoryW(LPCWSTR lpPathName, void* lpSecurityAttributes);
    BOOL MoveFileExW(LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, DWORD dwFlags);

    int MultiByteToWideChar(unsigned int CodePage, DWORD dwFlags, LPCSTR lpMultiByteStr, int cbMultiByte, LPWSTR lpWideCharStr, int cchWideChar);
    int WideCharToMultiByte(unsigned int CodePage, DWORD dwFlags, LPCWSTR lpWideCharStr, int cchWideChar, LPSTR lpMultiByteStr, int cbMultiByte, LPCSTR lpDefaultChar, BOOL* lpUsedDefaultChar);

    typedef struct {
        DWORD dwSize;
        DWORD cntUsage;
        DWORD th32ProcessID;
        ULONG_PTR th32DefaultHeapID;
        DWORD th32ModuleID;
        DWORD cntThreads;
        DWORD th32ParentProcessID;
        long pcPriClassBase;
        DWORD dwFlags;
        wchar_t szExeFile[260];
    } PROCESSENTRY32W;

    HANDLE CreateToolhelp32Snapshot(DWORD dwFlags, DWORD th32ProcessID);
    BOOL Process32FirstW(HANDLE hSnapshot, PROCESSENTRY32W* lppe);
    BOOL Process32NextW(HANDLE hSnapshot, PROCESSENTRY32W* lppe);
]]

local user32 = ffi.load("user32")
local kernel32 = ffi.load("kernel32")

-- Constants
local PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
local PROCESS_QUERY_INFORMATION = 0x0400
local PROCESS_VM_READ = 0x0010
local TH32CS_SNAPPROCESS = 0x00000002
local CP_UTF8 = 65001

-- Configuration
local destination_base_dir = "D:\\Videos"
local default_folder = "Unclassified"
local subfolder_by_date = false
local auto_start_replay_buffer = true

-- Executable-to-game folder rules
local game_rules = {
    ["valorant-win64-shipping.exe"] = "Valorant",
    ["valorant.exe"] = "Valorant",
    ["dungeoncrawler.exe"] = "Dark And Darker",
    ["dungeoncrawler-win64-shipping.exe"] = "Dark And Darker",
    ["cs2.exe"] = "CS2",
    ["csgo.exe"] = "CS2",
    ["r5apex_dx12.exe"] = "Apex Legends",
    ["r5apex.exe"] = "Apex Legends",
    ["project8.exe"] = "Deadlock",
    ["deadlock.exe"] = "Deadlock",
    ["marvel-win64-shipping.exe"] = "Marvel Rivals",
    ["marvelrivals.exe"] = "Marvel Rivals",
    ["fpsaimtrainer-win64-shipping.exe"] = "Kovaak's",
    ["fpsaimtrainer.exe"] = "Kovaak's",
    ["overwatch.exe"] = "Overwatch",
    ["rocketleague.exe"] = "Rocket League",
    ["chivalry2-win64-shipping.exe"] = "Chivalry",
    ["chivalry2.exe"] = "Chivalry",
    ["league of legends.exe"] = "League of Legends",
    ["fortniteclient-win64-shipping.exe"] = "Fortnite",
    ["javaw.exe"] = "Minecraft",
    ["gta5.exe"] = "GTA V",
    ["rustclient.exe"] = "Rust",
    ["helldivers2.exe"] = "Helldivers 2"
}

-- UTF-8 / UTF-16 conversion for Windows paths
local function to_wide(utf8_str)
    local len = kernel32.MultiByteToWideChar(CP_UTF8, 0, utf8_str, -1, nil, 0)
    if len <= 0 then return nil end
    local buf = ffi.new("wchar_t[?]", len)
    kernel32.MultiByteToWideChar(CP_UTF8, 0, utf8_str, -1, buf, len)
    return buf
end

local function from_wide(wide_str)
    local len = kernel32.WideCharToMultiByte(CP_UTF8, 0, wide_str, -1, nil, 0, nil, nil)
    if len <= 0 then return "" end
    local buf = ffi.new("char[?]", len)
    kernel32.WideCharToMultiByte(CP_UTF8, 0, wide_str, -1, buf, len, nil, nil)
    return ffi.string(buf)
end

local function get_filename_from_path(path)
    return path:match("^.+[/\\](.+)$") or path
end

-- ReplayRoute 2.0.1. Windows / OBS LuaJIT.
ffi.cdef[[
DWORD GetLastError(void);
DWORD GetFileAttributesW(LPCWSTR name);
unsigned int GetDriveTypeW(LPCWSTR root);
]]
local queue, history = {}, {}
local state_path = script_path() .. 'obs_organizer_state.json'
local loaded, storage_ok = false, true
local status, config_error = 'Loading', ''
local settings_ref
local process_queue, schedule
local fields = {'src','dst','exe','folder','reason','phase','error','attempts','next','month','original'}
local function norm(p) return (p or ''):gsub('/', '\\'):gsub('\\+$','') end
local function key(p) return norm(p):lower() end
local function exists(p) return kernel32.GetFileAttributesW(to_wide(p)) ~= 4294967295 end
local function directory(p)
    local a = tonumber(kernel32.GetFileAttributesW(to_wide(p)))
    return a ~= 4294967295 and bit.band(a,16) ~= 0
end
local function safe_folder(s)
    if not s or s == '' or s:find('[%z\1-\31<>:"/\\|?*]') or s:match('[%. ]$') then return false end
    local stem = s:match('^[^.]+'):upper()
    return not (stem == 'CON' or stem == 'PRN' or stem == 'AUX' or stem == 'NUL' or stem:match('^COM[1-9]$') or stem:match('^LPT[1-9]$'))
end
local function valid_base(p) return p:match('^[A-Za-z]:\\') ~= nil and not p:find('\\%.%.?[\\]?') end
local function mkdir(p)
    if directory(p) then return true end
    local parent = p:match('^(.*)\\[^\\]+$')
    if parent and parent:match('^[A-Za-z]:$') then parent=parent..'\\' end
    if not parent or #parent < 3 or parent==p then return false, 'Drive or folder unavailable: '..p end
    local ok, err = mkdir(parent)
    if not ok then return false, err end
    if kernel32.CreateDirectoryW(to_wide(p),nil) == 0 and not directory(p) then
        return false, 'Could not create folder (Windows '..tonumber(kernel32.GetLastError())..'): '..p
    end
    return true
end
local function note(s)
    status = s
    table.insert(history, os.date('%Y-%m-%d %H:%M:%S')..' '..s)
    while #history > 80 do table.remove(history,1) end
    obs.blog(obs.LOG_INFO, '[ReplayRoute] '..s)
end
local function serialize()
    local d = obs.obs_data_create()
    obs.obs_data_set_int(d,'version',2)
    local arr = obs.obs_data_array_create()
    for _,item in ipairs(queue) do
        local row = obs.obs_data_create()
        for _,f in ipairs(fields) do obs.obs_data_set_string(row,f,tostring(item[f] or '')) end
        obs.obs_data_array_push_back(arr,row); obs.obs_data_release(row)
    end
    obs.obs_data_set_array(d,'queue',arr); obs.obs_data_array_release(arr)
    obs.obs_data_set_string(d,'history',table.concat(history,'\n'))
    return d
end
local function persist()
    if not loaded then return true end
    local d = serialize()
    local ok = obs.obs_data_save_json_safe(d,state_path,'tmp','bak')
    obs.obs_data_release(d)
    storage_ok = ok
    if not ok then status = 'ERROR: unable to save the queue. Clip moves are paused. '..state_path end
    return ok
end
local function restore()
    local d = obs.obs_data_create_from_json_file_safe(state_path,'bak')
    if not d then
        if exists(state_path) or exists(state_path..'.bak') then
            status = 'ERROR: unreadable queue. Preserved without overwriting; inspect the JSON file.'
            storage_ok = false; return false
        end
        return true
    end
    if obs.obs_data_get_int(d,'version') ~= 2 then
        obs.obs_data_release(d); status = 'ERROR: unsupported queue version'; storage_ok=false; return false
    end
    local arr = obs.obs_data_get_array(d,'queue')
    if arr then
        local seen = {}
        for i=0,obs.obs_data_array_count(arr)-1 do
            local row = obs.obs_data_array_item(arr,i)
            local item = {}
            for _,f in ipairs(fields) do item[f] = obs.obs_data_get_string(row,f) end
            obs.obs_data_release(row)
            item.attempts = tonumber(item.attempts) or 0; item.next = tonumber(item.next) or 0
            if item.src ~= '' and not seen[key(item.src)] then
                seen[key(item.src)] = true; table.insert(queue,item)
            end
        end
        obs.obs_data_array_release(arr)
    end
    for line in obs.obs_data_get_string(d,'history'):gmatch('[^\n]+') do table.insert(history,line) end
    while #history>80 do table.remove(history,1) end
    obs.obs_data_release(d); return true
end
local function rules_text()
    local lines={}; for exe,folder in pairs(game_rules) do table.insert(lines,exe..' = '..folder) end
    table.sort(lines); return table.concat(lines,'\n')
end
local default_rules = rules_text()
local function parse_rules(text)
    local out={}
    for line in text:gmatch('[^\r\n]+') do
        if not line:match('^%s*$') then
            local exe,folder=line:match('^%s*(.-)%s*=%s*(.-)%s*$')
            if not exe or not exe:lower():match('%.exe$') or exe:find('[/\\:*?"<>|]') or not safe_folder(folder) then
                return nil,'Invalid rule: '..line
            end
            exe=exe:lower()
            if out[exe] then return nil,'Duplicate executable: '..exe end
            out[exe]=folder
        end
    end
    return out
end
local function foreground()
    local pid=ffi.new('DWORD[1]'); local hwnd=user32.GetForegroundWindow()
    if hwnd==nil then return nil end
    user32.GetWindowThreadProcessId(hwnd,pid)
    local h=kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,0,pid[0])
    if h==nil then return nil end
    local p=ffi.new('wchar_t[32768]'); local n=ffi.new('DWORD[1]',32768)
    local ok=kernel32.QueryFullProcessImageNameW(h,0,p,n); kernel32.CloseHandle(h)
    if ok==0 then return nil end
    return get_filename_from_path(from_wide(p)):lower()
end
-- Only visible game captures in the program scene; settings indicate a target,
-- not proof of a successful hook. Conflicting targets are never guessed.
local function capture_targets()
    local targets, visited={},{}
    local function walk(scene,depth)
        if not scene or depth>12 then return end
        local items=obs.obs_scene_enum_items(scene)
        if not items then return end
        for _,item in ipairs(items) do
            if obs.obs_sceneitem_visible(item) then
                local source=obs.obs_sceneitem_get_source(item)
                local name=obs.obs_source_get_name(source)
                if not visited[name] then
                    visited[name]=true
                    local id=obs.obs_source_get_id(source)
                    if id=='game_capture' then
                        local s=obs.obs_source_get_settings(source)
                        if obs.obs_data_get_string(s,'capture_mode')=='window' then
                            local w=obs.obs_data_get_string(s,'window')
                            local exe=w:match(':([^:]+)$')
                            if exe and exe:lower():match('%.exe$') then targets[exe:lower()]=true end
                        end
                        obs.obs_data_release(s)
                    end
                    if obs.obs_sceneitem_is_group(item) then
                        walk(obs.obs_sceneitem_group_get_scene(item),depth+1)
                    elseif id=='scene' then walk(obs.obs_scene_from_source(source),depth+1) end
                end
            end
        end
        obs.sceneitem_list_release(items)
    end
    local s=obs.obs_frontend_get_current_scene()
    if s then walk(obs.obs_scene_from_source(s),0); obs.obs_source_release(s) end
    return targets
end
local function detect()
    local t=capture_targets(); local fg=foreground(); local count,only=0,nil
    for exe in pairs(t) do count=count+1; only=exe end
    if count>1 then return '',nil,'Multiple visible Game Capture targets' end
    if count==1 then
        if fg and game_rules[fg] and fg~=only then return '',nil,'Game Capture and foreground game disagree' end
        return only,game_rules[only],'Configured Game Capture target'
    end
    if fg and game_rules[fg] then return fg,game_rules[fg],'Recognized foreground window' end
    return fg or '',nil,'No specific capture target or recognized foreground window'
end
local function destination(item)
    local folder=item.folder~='' and item.folder or default_folder
    if not valid_base(destination_base_dir) or not safe_folder(folder) then return nil,'Invalid destination' end
    local dir=destination_base_dir..'\\'..folder
    if kernel32.GetDriveTypeW(to_wide(destination_base_dir:sub(1,3)))==4 then return nil,'Network drive: choose a local destination' end
    if subfolder_by_date then dir=dir..'\\'..item.month end
    -- Never allow cross-volume copying in OBS's timer callback.
    if item.src:sub(1,2):lower()~=dir:sub(1,2):lower() then return nil,'Different drive: move the clip manually or choose its source drive' end
    local ok,err=mkdir(dir); if not ok then return nil,err end
    local name=get_filename_from_path(item.src)
    local stem,ext=name:match('^(.*)(%.[^.]*)$'); stem=stem or name; ext=ext or ''
    for n=0,9999 do
        local path=dir..'\\'..stem..(n==0 and '' or ' ('..n..')')..ext
        if key(path)==key(item.src) or not exists(path) then return path end
    end
    return nil,'Too many filename collisions'
end
local function fail(item,message,permanent)
    item.error=message; item.attempts=item.attempts+1
    item.phase=(permanent or item.attempts>=6) and 'blocked' or 'pending'
    item.next=os.time()+math.min(60,2^item.attempts)
    note(get_filename_from_path(item.src)..': '..message..' ['..item.phase..']')
    persist()
end
local function complete(item)
    item.src=item.dst; item.dst=''; item.error=''; item.attempts=0
    item.phase=item.folder=='' and 'unclassified' or 'done'
    note('Saved: '..item.src..' | '..item.reason)
    -- Only completed receipts are bounded. Unresolved clips are never discarded.
    local count=0
    for i=#queue,1,-1 do
        if queue[i].phase=='done' then count=count+1; if count>100 then table.remove(queue,i) end end
    end
    persist()
end
process_queue=function()
    if not storage_ok or config_error~='' then obs.timer_remove(process_queue); return end
    local now=os.time(); local waiting=false
    for _,item in ipairs(queue) do
        if item.phase=='pending' or item.phase=='moving' then
            waiting=true
            if item.next<=now then
                if item.phase=='moving' and not exists(item.src) then
                    if item.dst~='' and exists(item.dst) then complete(item)
                    else fail(item,'Source missing; inspect the file before retrying',true) end
                elseif not exists(item.src) then fail(item,'Source missing',true)
                else
                    local dst,err=destination(item)
                    if not dst then fail(item,err,true)
                    elseif key(dst)==key(item.src) then item.dst=dst; complete(item)
                    else
                        item.dst=dst; item.phase='moving'
                        if not persist() then return end -- durable intent before rename
                        -- flags=0: atomic same-volume rename, NO replace and NO copy.
                        if kernel32.MoveFileExW(to_wide(item.src),to_wide(dst),0)~=0 then complete(item)
                        else
                            local code=tonumber(kernel32.GetLastError())
                            item.dst=''
                            fail(item,'Windows '..code,code~=32 and code~=33 and code~=80 and code~=183)
                        end
                    end
                end
                return -- one clip per tick, never a long batch in OBS
            end
        end
    end
    if not waiting then obs.timer_remove(process_queue) end
end
schedule=function() obs.timer_remove(process_queue); obs.timer_add(process_queue,1000) end
local function enqueue(path)
    path=norm(path)
    for _,item in ipairs(queue) do
        if key(item.src)==key(path) then return end
        if key(item.original)==key(path) then
            if item.phase=='pending' or item.phase=='moving' or item.phase=='blocked' or not exists(path) then return end
        end
    end
    local exe,folder,why=detect()
    table.insert(queue,{src=path,original=path,dst='',exe=exe,folder=folder or '',reason=why,
        phase='pending',error='',attempts=0,next=os.time()+1,month=os.date('%Y-%m')})
    note('Queued: '..path..' | '..why..' | '..exe)
    if persist() then schedule() end
end
local function retry()
    if not loaded then return end
    if not persist() then return end
    for _,item in ipairs(queue) do
        if item.phase=='blocked' then item.phase='pending'; item.attempts=0; item.next=0 end
        if item.phase=='unclassified' and game_rules[item.exe] then
            item.folder=game_rules[item.exe]; item.phase='pending'; item.attempts=0; item.next=0
        elseif item.phase=='pending' and item.folder=='' and game_rules[item.exe] then item.folder=game_rules[item.exe] end
    end
    if persist() then schedule() end
end
local buffer_status='Not checked'
local function verify_buffer()
    obs.timer_remove(verify_buffer)
    buffer_status=obs.obs_frontend_replay_buffer_active() and 'Active' or 'Not active: check Settings > Output and the OBS log'
    note('Replay Buffer: '..buffer_status)
end
local function start_buffer()
    obs.timer_remove(start_buffer)
    if auto_start_replay_buffer and not obs.obs_frontend_replay_buffer_active() then
        obs.obs_frontend_replay_buffer_start()
        buffer_status='Start requested; awaiting confirmation'
        obs.timer_add(verify_buffer,3000)
    else verify_buffer() end
end
local function on_event(event)
    if event==obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
        local p=obs.obs_frontend_get_last_replay(); if p and p~='' then enqueue(p) end
    elseif event==obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_STARTED then
        obs.timer_remove(verify_buffer); buffer_status='Active'; note('Replay Buffer active')
    elseif event==obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_STOPPED then
        buffer_status='Stopped'; note('Replay Buffer stopped')
    end
end
local function report()
    local lines={'Replay Buffer: '..(obs.obs_frontend_replay_buffer_active() and 'Active' or buffer_status),status}
    if config_error~='' then table.insert(lines,config_error) end
    if not storage_ok then table.insert(lines,'STORAGE ERROR: clips remain at their source') end
    local counts={}
    for _,item in ipairs(queue) do counts[item.phase]=(counts[item.phase] or 0)+1 end
    table.insert(lines,string.format('Pending: %d | Blocked: %d | Unclassified: %d',
        (counts.pending or 0)+(counts.moving or 0),counts.blocked or 0,counts.unclassified or 0))
    for _,item in ipairs(queue) do
        if item.phase~='done' then table.insert(lines,item.phase..' | '..item.exe..' | '..get_filename_from_path(item.src)..' | '..item.error) end
        if #lines>=25 then table.insert(lines,'More items in '..state_path); break end
    end
    table.insert(lines,'Recent history:')
    for i=math.max(1,#history-7),#history do table.insert(lines,history[i]) end
    return table.concat(lines,'\n')
end
local function refresh_ui(p)
    local info=obs.obs_properties_get(p,'status_info')
    if info then obs.obs_property_set_description(info,report()) end
    local selection=obs.obs_properties_get(p,'selected_clip')
    if selection then
        obs.obs_property_list_clear(selection)
        obs.obs_property_list_add_string(selection,'Only apply the rule to matching executables','')
        for _,item in ipairs(queue) do
            if item.phase~='done' then obs.obs_property_list_add_string(selection,get_filename_from_path(item.src)..' | '..item.exe,item.src) end
        end
    end
    return true
end
function script_description()
    return '<h2>ReplayRoute 2.0.1</h2><p>No overwrites. Recoverable queue. Same-drive moves only.</p><p>Rules: executable.exe = Folder, one per line. Click Refresh status to see results.</p>'
end
function script_defaults(s)
    obs.obs_data_set_default_string(s,'destination_base_dir','D:\\Videos')
    obs.obs_data_set_default_string(s,'default_folder','Unclassified')
    obs.obs_data_set_default_bool(s,'subfolder_by_date',false)
    obs.obs_data_set_default_bool(s,'auto_start_replay_buffer',true)
    obs.obs_data_set_default_string(s,'game_rules_v2',default_rules)
end
function script_update(s)
    destination_base_dir=norm(obs.obs_data_get_string(s,'destination_base_dir'))
    default_folder=obs.obs_data_get_string(s,'default_folder')
    subfolder_by_date=obs.obs_data_get_bool(s,'subfolder_by_date')
    auto_start_replay_buffer=obs.obs_data_get_bool(s,'auto_start_replay_buffer')
    local parsed,err=parse_rules(obs.obs_data_get_string(s,'game_rules_v2'))
    config_error=err or ''
    if parsed then game_rules=parsed end
    if not valid_base(destination_base_dir) or not safe_folder(default_folder) then config_error='Invalid folder: use an absolute local path and a single subfolder name' end
    if settings_ref~=s then
        if settings_ref then obs.obs_data_release(settings_ref) end
        settings_ref=s; obs.obs_data_addref(s)
    end
    if loaded and config_error=='' then schedule() end
end
function script_properties()
    local p=obs.obs_properties_create()
    obs.obs_properties_add_path(p,'destination_base_dir','Base folder (same drive as the clips)',obs.OBS_PATH_DIRECTORY,nil,nil)
    obs.obs_properties_add_text(p,'default_folder','Unclassified folder (existing preference is preserved)',obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_bool(p,'subfolder_by_date','Create year-month subfolders')
    obs.obs_properties_add_bool(p,'auto_start_replay_buffer','Start Replay Buffer when the script loads')
    obs.obs_properties_add_text(p,'game_rules_v2','Games: executable.exe = Folder (edit / add / remove lines)',obs.OBS_TEXT_MULTILINE)
    obs.obs_properties_add_text(p,'manual_exe','Executable to classify pending clips (e.g. newgame.exe)',obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(p,'manual_folder','Folder for this executable',obs.OBS_TEXT_DEFAULT)
    local selection=obs.obs_properties_add_list(p,'selected_clip','Clip to reclassify (optional)',obs.OBS_COMBO_TYPE_LIST,obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(selection,'Only apply the rule to matching executables','')
    for _,item in ipairs(queue) do
        if item.phase~='done' then obs.obs_property_list_add_string(selection,get_filename_from_path(item.src)..' | '..item.exe,item.src) end
    end
    obs.obs_properties_add_button(p,'classify_clip','Assign folder to selected clip',function(props)
        if not settings_ref then return false end
        local selected=obs.obs_data_get_string(settings_ref,'selected_clip')
        local folder=obs.obs_data_get_string(settings_ref,'manual_folder'):match('^%s*(.-)%s*$')
        if not safe_folder(folder) then note('Invalid folder name'); return refresh_ui(props) end
        for _,item in ipairs(queue) do
            if item.src==selected and item.phase~='done' then
                item.folder=folder; item.reason='Manual assignment'; item.phase='pending'; item.attempts=0; item.next=0
                if persist() then schedule() end
                return refresh_ui(props)
            end
        end
        note('Select a pending clip'); return refresh_ui(props)
    end)
    obs.obs_properties_add_button(p,'apply_rule','Save rule and reclassify',function(props)
        if not settings_ref then return false end
        local exe=obs.obs_data_get_string(settings_ref,'manual_exe'):lower():match('^%s*(.-)%s*$')
        local folder=obs.obs_data_get_string(settings_ref,'manual_folder'):match('^%s*(.-)%s*$')
        local check,err=parse_rules(exe..' = '..folder)
        if not check then note(err); return refresh_ui(props) end
        game_rules[exe]=folder
        obs.obs_data_set_string(settings_ref,'game_rules_v2',rules_text())
        script_update(settings_ref); retry(); return refresh_ui(props)
    end)
    obs.obs_properties_add_button(p,'retry','Retry pending clips and apply rules',function(props) retry(); return refresh_ui(props) end)
    obs.obs_properties_add_button(p,'refresh','Refresh status',refresh_ui)
    local info=obs.obs_properties_add_text(p,'status_info',report(),obs.OBS_TEXT_INFO)
    return p
end
function script_load(s)
    script_update(s)
    if not restore() then return end
    loaded=true
    note('ReplayRoute 2.0.1 loaded; queue restored')
    obs.obs_frontend_add_event_callback(on_event)
    if persist() then schedule() end
    obs.timer_add(start_buffer,1000)
end
function script_save(s) if loaded then persist() end end
function script_unload()
    obs.timer_remove(process_queue); obs.timer_remove(start_buffer); obs.timer_remove(verify_buffer)
    obs.obs_frontend_remove_event_callback(on_event)
    if loaded then persist() end
    if settings_ref then obs.obs_data_release(settings_ref); settings_ref=nil end
end
-- Test-only exports: absent in normal OBS execution.
if rawget(_G,'OBS_ORGANIZER_TEST') then
    OBS_ORGANIZER_TEST={safe_folder=safe_folder,parse_rules=parse_rules,detect=detect,
        enqueue=enqueue,tick=process_queue,retry=retry,queue=queue,report=report,persist=persist,destination=destination}
end
