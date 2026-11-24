--[[
    ReplayRoute 2.3.0 - OBS Replay Buffer clip organizer for Windows.
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
local TH32CS_SNAPPROCESS = 0x00000002
local CP_UTF8 = 65001

-- Configuration
local destination_base_dir = "D:\\Videos"
local default_folder = "Unclassified"
local subfolder_by_date = false
local auto_start_replay_buffer = true
local auto_create_game_folders = true

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

ffi.cdef[[
DWORD GetLastError(void);
DWORD GetFileAttributesW(LPCWSTR name);
unsigned int GetDriveTypeW(LPCWSTR root);
BOOL GetVolumePathNameW(LPCWSTR path, LPWSTR mount, DWORD length);
BOOL GetVolumeNameForVolumeMountPointW(LPCWSTR mount, LPWSTR volume, DWORD length);
BOOL RemoveDirectoryW(LPCWSTR lpPathName);
]]
if not pcall(ffi.typeof,'RR_WIN32_FIND_DATAW') then
    ffi.cdef[[
    typedef struct { DWORD dwLowDateTime; DWORD dwHighDateTime; } RR_FILETIME;
    typedef struct {
        DWORD dwFileAttributes;
        RR_FILETIME ftCreationTime;
        RR_FILETIME ftLastAccessTime;
        RR_FILETIME ftLastWriteTime;
        DWORD nFileSizeHigh;
        DWORD nFileSizeLow;
        DWORD dwReserved0;
        DWORD dwReserved1;
        wchar_t cFileName[260];
        wchar_t cAlternateFileName[14];
    } RR_WIN32_FIND_DATAW;
    HANDLE FindFirstFileW(LPCWSTR lpFileName, RR_WIN32_FIND_DATAW* lpFindFileData);
    BOOL FindNextFileW(HANDLE hFindFile, RR_WIN32_FIND_DATAW* lpFindFileData);
    BOOL FindClose(HANDLE hFindFile);
    ]]
end
local queue, history = {}, {}
local state_path = script_path() .. 'obs_organizer_state.json'
local loaded, storage_ok = false, true
local status, config_error = 'Loading', ''
local settings_ref
local process_queue, schedule
local fields = {'src','dst','exe','folder','reason','phase','error','attempts','next','month','original','routing'}
local function norm(p)
    p=(p or ''):gsub('/', '\\')
    local prefix=p:sub(1,2)=='\\\\' and '\\' or ''
    p=prefix..(p:gsub('\\+','\\'))
    if p:match('^[A-Za-z]:\\+$') then return p:sub(1,3) end
    return (p:gsub('\\+$',''))
end
local function key(p) return norm(p):lower() end
local function exists(p) return kernel32.GetFileAttributesW(to_wide(p)) ~= 4294967295 end
local function directory(p)
    local a = tonumber(kernel32.GetFileAttributesW(to_wide(p)))
    return a ~= 4294967295 and bit.band(a,16) ~= 0
end
local function is_reserved_name(s)
    local stem = (s:match('^[^.]+') or ''):upper()
    return stem == 'CON' or stem == 'PRN' or stem == 'AUX' or stem == 'NUL'
        or stem:match('^COM[1-9]$') ~= nil or stem:match('^LPT[1-9]$') ~= nil
end
local function safe_folder(s)
    if not s or s == '' or s:find('[%z\1-\31<>:"/\\|?*]') or s:match('[%. ]$') then return false end
    if s:sub(1,1) == '.' then return false end
    return not is_reserved_name(s)
end
local function valid_base(p)
    if not p:match('^[A-Za-z]:\\') then return false end
    for part in p:sub(4):gmatch('[^\\]+') do
        if part=='..' or part=='.' or part:find('[%z\1-\31<>:"|?*]') or part:match('[%. ]$') or is_reserved_name(part) then return false end
    end
    return true
end
local function join(dir,name)
    return dir..(dir:sub(-1)=='\\' and '' or '\\')..name
end
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
local function local_mount(path)
    local mount=ffi.new('wchar_t[32768]')
    if kernel32.GetVolumePathNameW(to_wide(path),mount,32768)==0 then return nil end
    if kernel32.GetDriveTypeW(mount)==4 then return nil end
    return from_wide(mount):lower()
end
local function same_volume(src,dir)
    local a,b=local_mount(src),local_mount(dir)
    if not a or not b then return false end
    if a==b then return true end
    local first,second=ffi.new('wchar_t[64]'),ffi.new('wchar_t[64]')
    return kernel32.GetVolumeNameForVolumeMountPointW(to_wide(a),first,64)~=0
       and kernel32.GetVolumeNameForVolumeMountPointW(to_wide(b),second,64)~=0
       and from_wide(first):lower()==from_wide(second):lower()
end
local function note(s)
    status = s
    table.insert(history, os.date('%Y-%m-%d %H:%M:%S')..' '..s)
    while #history > 80 do table.remove(history,1) end
    obs.blog(obs.LOG_INFO, '[ReplayRoute] '..s)
end
local function serialize(rows)
    local d = obs.obs_data_create()
    obs.obs_data_set_int(d,'version',2)
    local arr = obs.obs_data_array_create()
    for _,item in ipairs(rows or queue) do
        local row = obs.obs_data_create()
        for _,f in ipairs(fields) do obs.obs_data_set_string(row,f,tostring(item[f] or '')) end
        obs.obs_data_array_push_back(arr,row); obs.obs_data_release(row)
    end
    obs.obs_data_set_array(d,'queue',arr); obs.obs_data_array_release(arr)
    obs.obs_data_set_string(d,'history',table.concat(history,'\n'))
    return d
end
local function persist(rows)
    if not loaded then return true end
    local d = serialize(rows)
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
local function rules_text(rules)
    local lines={}; for exe,folder in pairs(rules or game_rules) do table.insert(lines,exe..' = '..folder) end
    table.sort(lines); return table.concat(lines,'\n')
end
local learned={}
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
local function retain_running(recent)
    if not next(recent) then return end
    local missing={}
    for exe in pairs(recent) do missing[exe]=true end
    local snapshot=kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0)
    if snapshot~=nil and snapshot~=ffi.cast('HANDLE',-1) then
        local entry=ffi.new('PROCESSENTRY32W[1]')
        entry[0].dwSize=ffi.sizeof('PROCESSENTRY32W')
        local more=kernel32.Process32FirstW(snapshot,entry)
        while more~=0 do
            missing[from_wide(entry[0].szExeFile):lower()]=nil
            if not next(missing) then break end
            more=kernel32.Process32NextW(snapshot,entry)
        end
        kernel32.CloseHandle(snapshot)
    end
    for exe in pairs(missing) do
        recent[exe].exe=nil
        recent[exe]=nil
    end
end

local function executable(value,allow_path)
    if not value then return nil end
    if allow_path and (value:match('^[A-Za-z]:[/\\]') or value:match('^\\\\')) then
        value=get_filename_from_path(value)
    end
    value=value:lower()
    if value:match('^.+%.exe$') and not value:find('[%c<>:"/\\|?*]') then return value end
end

local function hook_info(source)
    if not obs.obs_source_get_proc_handler or not obs.calldata_create then return false end
    local handler=obs.obs_source_get_proc_handler(source)
    if not handler then return false end
    local data=obs.calldata_create()
    if not data then return false end
    local hooked=obs.proc_handler_call(handler,'get_hooked',data) and obs.calldata_bool(data,'hooked')
    local exe
    if hooked then exe=executable(obs.calldata_string(data,'executable'),true) end
    obs.calldata_destroy(data)
    return hooked,exe
end

-- Listen for capture loss even before the user's first replay. Only visible
-- Game Capture sources in the program scene retain a reference and a signal pair.
local GRACE_NS=45*1000000000
local watches,program_scene={},nil
local function source_key(source)
    return obs.obs_source_get_uuid and obs.obs_source_get_uuid(source) or obs.obs_source_get_name(source)
end
local function remember(watch,exe)
    watch.exe=exe
    watch.seen=obs.os_gettime_ns()
    watch.lost=nil
end
local function watch_game(source,id)
    if watches[id] then return watches[id] end
    local ref=obs.obs_source_get_ref(source)
    if not ref then return nil end
    local watch={source=ref}
    watch.on_hook=function(data) remember(watch,executable(obs.calldata_string(data,'executable'),true)) end
    watch.on_loss=function()
        if watch.exe and not watch.lost then watch.lost=obs.os_gettime_ns() end
    end
    local handler=obs.obs_source_get_signal_handler(source)
    obs.signal_handler_connect(handler,'hooked',watch.on_hook)
    obs.signal_handler_connect(handler,'unhooked',watch.on_loss)
    watches[id]=watch
    return watch
end
local function release_watch(id)
    local watch=watches[id]
    local handler=obs.obs_source_get_signal_handler(watch.source)
    obs.signal_handler_disconnect(handler,'hooked',watch.on_hook)
    obs.signal_handler_disconnect(handler,'unhooked',watch.on_loss)
    obs.obs_source_release(watch.source)
    watches[id]=nil
end
local function clear_watches()
    for id in pairs(watches) do release_watch(id) end
    program_scene=nil
end

local function configured_game(source)
    local s=obs.obs_source_get_settings(source)
    local exe
    if obs.obs_data_get_string(s,'capture_mode')=='window' then
        exe=executable(obs.obs_data_get_string(s,'window'):match(':([^:]+)$'))
    end
    obs.obs_data_release(s)
    return exe
end
local function capture_targets()
    local live,configured,recent,visited={},{},{},{}
    local unidentified_game=false
    local other_window=false
    local function inspect(source,id,kind)
        local hooked,exe=hook_info(source)
        if kind=='window_capture' then
            if hooked and exe and game_rules[exe] then
                live[exe]=live[exe] or 'Window Capture'
            elseif hooked then
                other_window=true
            end
            return
        end
        local watch=watch_game(source,id)
        if hooked then
            if watch then remember(watch,exe) end
            if exe then live[exe]='Game Capture' else unidentified_game=true end
            return
        end
        local target=configured_game(source)
        if target then configured[target]=true end
        if watch and watch.exe then
            -- If a loss signal was missed, count from the last positive observation.
            watch.lost=watch.lost or watch.seen
            if obs.os_gettime_ns()-watch.lost <= GRACE_NS then
                recent[watch.exe]=watch
            else
                watch.exe=nil
            end
        end
    end
    local function walk(scene,depth)
        if not scene or depth>12 then return end
        local items=obs.obs_scene_enum_items(scene)
        if not items then return end
        for _,item in ipairs(items) do
            if obs.obs_sceneitem_visible(item) then
                local source=obs.obs_sceneitem_get_source(item)
                local key=source_key(source)
                if not visited[key] then
                    visited[key]=true
                    local kind=obs.obs_source_get_id(source)
                    if kind=='game_capture' or kind=='window_capture' then inspect(source,key,kind) end
                    if obs.obs_sceneitem_is_group(item) then
                        walk(obs.obs_sceneitem_group_get_scene(item),depth+1)
                    elseif kind=='scene' then walk(obs.obs_scene_from_source(source),depth+1) end
                end
            end
        end
        obs.sceneitem_list_release(items)
    end
    local s=obs.obs_frontend_get_current_scene()
    local scene_id=s and source_key(s)
    if scene_id~=program_scene then clear_watches(); program_scene=scene_id end
    if s then walk(obs.obs_scene_from_source(s),0); obs.obs_source_release(s) end
    for id in pairs(watches) do if not visited[id] then release_watch(id) end end
    return live,configured,recent,unidentified_game,other_window
end
local function folder_match_key(s)
    return (s or ''):lower():gsub('[%s_%-%.]+','')
end
local function clean_game_stem(exe)
    local raw=exe:match('^(.*)%.exe$')
    if not raw then return nil end
    local trimmed=raw
    local suffixes={'%-win64%-shipping$','%-win32%-shipping$','%-shipping$','[_%-]dx12$','[_%-]dx11$','[_%-]vulkan$'}
    local changed=true
    while changed do
        changed=false
        for _,pat in ipairs(suffixes) do
            local next_stem=trimmed:gsub(pat,'')
            if next_stem~=trimmed then trimmed=next_stem; changed=true end
        end
    end
    if trimmed~='' and #trimmed<=120 and safe_folder(trimmed) then return trimmed,raw end
    if raw~='' and #raw<=120 and safe_folder(raw) then return raw,raw end
    return nil
end
local function find_existing_folder(clean_stem,raw_stem)
    if not valid_base(destination_base_dir) or not directory(destination_base_dir) then return nil end
    local clean_key,raw_key=folder_match_key(clean_stem),folder_match_key(raw_stem)
    if clean_key=='' then return nil end
    local fd=ffi.new('RR_WIN32_FIND_DATAW')
    local handle=kernel32.FindFirstFileW(to_wide(join(destination_base_dir,'*')),fd)
    if handle==nil or handle==ffi.cast('HANDLE',-1) then return nil end
    local clean_hits,raw_hits={},{}
    local unclass=default_folder:lower()
    repeat
        local name=from_wide(fd.cFileName)
        if name~='.' and name~='..' and bit.band(tonumber(fd.dwFileAttributes),16)~=0
            and safe_folder(name) and name:lower()~=unclass then
            local k=folder_match_key(name)
            if k==clean_key then table.insert(clean_hits,name)
            elseif raw_key~=clean_key and k==raw_key then table.insert(raw_hits,name) end
        end
    until kernel32.FindNextFileW(handle,fd)==0
    kernel32.FindClose(handle)
    if #clean_hits==1 then return clean_hits[1] end
    if #clean_hits==0 and #raw_hits==1 then return raw_hits[1] end
    return nil
end
local function prune_empty_dirs(old_src,item)
    if not old_src or old_src=='' then return end
    local base=norm(destination_base_dir)
    if not valid_base(base) then return end
    local orig_dir=norm(item.original):match('^(.*)\\[^\\]+$') or ''
    local unclass_dir=norm(join(base,default_folder))
    local base_prefix=base:lower()..(base:sub(-1)=='\\' and '' or '\\')
    local dir=norm(old_src):match('^(.*)\\[^\\]+$')
    for _=1,2 do
        if not dir or dir=='' then break end
        local dkey=key(dir)
        if dkey==key(base) or dkey==key(orig_dir) or dkey==key(unclass_dir) then break end
        if dkey:sub(1,#base_prefix)~=base_prefix then break end
        if kernel32.RemoveDirectoryW(to_wide(dir))==0 then break end
        dir=dir:match('^(.*)\\[^\\]+$')
    end
end
local function classify(exe,reason,can_learn)
    local folder=game_rules[exe]
    if folder then return exe,folder,reason,learned[exe]==folder and 'auto' or nil end
    local clean_stem,raw_stem=clean_game_stem(exe)
    if can_learn and auto_create_game_folders and clean_stem and not exe:find('=') then
        local existing=find_existing_folder(clean_stem,raw_stem)
        if existing then return exe,existing,reason..' (matched existing folder)','auto' end
        return exe,clean_stem,reason,'auto'
    end
    return exe,nil,'Unregistered game: '..exe
end
local function detect()
    local live,configured,recent,unidentified,other_window=capture_targets()
    local exe,kind=next(live)
    if unidentified or (exe and next(live,exe)) then return '',nil,'Ambiguous or unidentified live capture' end
    if exe then return classify(exe,'Captured by '..kind,kind=='Game Capture') end

    local fg=foreground()
    local target=next(configured)
    if target and next(configured,target) then return '',nil,'Multiple configured Game Capture targets' end
    retain_running(recent)
    for candidate in pairs(recent) do
        if target and target~=candidate then return '',nil,'Conflicting recent and configured games' end
        target=candidate
    end
    if target then
        if fg and game_rules[fg] and fg~=target then return '',nil,'Capture and foreground game disagree' end
        return classify(target,configured[target] and 'Configured Game Capture target' or 'Recent Game Capture after Alt-Tab',true)
    end
    if other_window then return '',nil,'Window Capture is capturing an unregistered window' end
    if fg and game_rules[fg] then return classify(fg,'Recognized foreground window',false) end
    return fg or '',nil,'No capture target or recognized foreground game'
end
local function destination(item)
    local folder=item.folder~='' and item.folder or default_folder
    if not valid_base(destination_base_dir) or not safe_folder(folder) then return nil,'Invalid destination' end
    local dir=join(destination_base_dir,folder)
    if kernel32.GetDriveTypeW(to_wide(destination_base_dir:sub(1,3)))==4 then return nil,'Network drive: choose a local destination' end
    if subfolder_by_date then dir=dir..'\\'..item.month end
    -- Never allow cross-volume copying in OBS's timer callback.
    if item.src:sub(1,2):lower()~=dir:sub(1,2):lower() then return nil,'Different drive: move the clip manually or choose its source drive' end
    if not same_volume(item.src,dir) then return nil,'Choose a folder on the same local volume as the clip' end
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
local function trim_completed(rows)
    local count=0
    for _,item in ipairs(rows) do if item.phase=='done' then count=count+1 end end
    if count<=100 then return end
    local keep=1
    for _,item in ipairs(rows) do
        if item.phase=='done' and count>100 then count=count-1
        else
            rows[keep]=item
            keep=keep+1
        end
    end
    for i=#rows,keep,-1 do rows[i]=nil end
end
local function complete(item)
    item.src=item.dst; item.dst=''; item.error=''; item.attempts=0
    item.phase=item.folder=='' and 'unclassified' or (item.routing=='auto' and 'auto_routed' or 'done')
    if item.routing=='auto' and not game_rules[item.exe] and settings_ref and config_error=='' then
        learned[item.exe]=item.folder
        game_rules[item.exe]=item.folder
        obs.obs_data_set_string(settings_ref,'game_rules_v2',rules_text())
        obs.obs_data_set_string(settings_ref,'learned_games',rules_text(learned))
    end
    note('Saved: '..item.src..' | '..item.reason)
    trim_completed(queue)
    persist()
end
local timer_ms=0
local function stop_queue_timer()
    obs.timer_remove(process_queue)
    timer_ms=0
end
local function queue_state(now)
    local waiting,ready=false,false
    for _,item in ipairs(queue) do
        if item.phase=='pending' or item.phase=='moving' then
            waiting=true
            if item.next<=now then ready=true; break end
        end
    end
    return waiting,ready
end
schedule=function()
    local waiting,ready=queue_state(os.time())
    if not waiting then stop_queue_timer(); return end
    local ms=ready and 200 or 1000
    if timer_ms~=ms then
        obs.timer_remove(process_queue)
        obs.timer_add(process_queue,ms)
        timer_ms=ms
    end
end
process_queue=function()
    if not storage_ok or config_error~='' then stop_queue_timer(); return false end
    local now=os.time()
    for _,item in ipairs(queue) do
        if (item.phase=='pending' or item.phase=='moving') and item.next<=now then
            if item.phase=='moving' and not exists(item.src) then
                if item.dst~='' and exists(item.dst) then
                    local prev_src=item.src
                    complete(item)
                    prune_empty_dirs(prev_src,item)
                else fail(item,'Source missing; inspect the file before retrying',true) end
            elseif not exists(item.src) then fail(item,'Source missing',true)
            else
                local dst,err=destination(item)
                if not dst then fail(item,err,true)
                elseif key(dst)==key(item.src) then item.dst=dst; complete(item)
                else
                    item.dst=dst; item.phase='moving'
                    if not persist() then stop_queue_timer(); return false end -- durable intent before rename
                    -- flags=0: atomic same-volume rename, NO replace and NO copy.
                    if kernel32.MoveFileExW(to_wide(item.src),to_wide(dst),0)~=0 then
                        local prev_src=item.src
                        complete(item)
                        prune_empty_dirs(prev_src,item)
                    else
                        local code=tonumber(kernel32.GetLastError())
                        item.dst=''
                        fail(item,'Windows '..code,code~=32 and code~=33 and code~=80 and code~=183)
                    end
                end
            end
            schedule()
            return true -- one clip per tick, never a long batch in OBS
        end
    end
    schedule()
    return false
end
local function flush_ready(limit)
    for _=1,(limit or 10) do
        if not process_queue() then break end
    end
end
local function enqueue(path)
    path=norm(path)
    for _,item in ipairs(queue) do
        if key(item.src)==key(path) then return end
        if key(item.original)==key(path) then
            if item.phase=='pending' or item.phase=='moving' or item.phase=='blocked' or not exists(path) then return end
        end
    end
    local exe,folder,why,routing=detect()
    table.insert(queue,{src=path,original=path,dst='',exe=exe,folder=folder or '',reason=why,
        phase='pending',error='',attempts=0,next=0,month=os.date('%Y-%m'),routing=routing or ''})
    note('Queued: '..path..' | '..why..' | '..exe)
    if persist() then schedule() end
end
local function retry()
    if not loaded or config_error~='' then return end
    if not persist() then return end
    for _,item in ipairs(queue) do
        if item.phase=='blocked' then item.phase='pending'; item.attempts=0; item.next=0 end
        if (item.phase=='unclassified' or (item.phase=='auto_routed' and learned[item.exe]~=item.folder)) and game_rules[item.exe] then
            item.folder=game_rules[item.exe]; item.routing=''; item.phase='pending'; item.attempts=0; item.next=0
        elseif item.phase=='pending' and (item.folder=='' or (item.routing=='auto' and learned[item.exe]~=item.folder)) and game_rules[item.exe] then
            item.folder=game_rules[item.exe]; item.routing=''
        end
    end
    if persist() then schedule() end
end
local function sync_visible()
    obs.timer_remove(sync_visible)
    if loaded then capture_targets() end
end
local function request_sync()
    obs.timer_remove(sync_visible)
    obs.timer_add(sync_visible,50)
end
local function on_visibility_change(data)
    local source=obs.calldata_source(data,'source')
    if source and obs.obs_source_get_id(source)=='game_capture' then
        local watch=watches[source_key(source)]
        if watch then watch.exe=nil end
        -- Source signals can arrive mid-transition. Read the final program scene
        -- on the next timer turn rather than entering the frontend from a signal.
        request_sync()
    end
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
    elseif event==obs.OBS_FRONTEND_EVENT_SCENE_CHANGED or event==obs.OBS_FRONTEND_EVENT_SCENE_COLLECTION_CHANGED then
        clear_watches()
        request_sync()
    elseif event==obs.OBS_FRONTEND_EVENT_FINISHED_LOADING then
        request_sync()
        obs.timer_remove(start_buffer)
        obs.timer_add(start_buffer,1000)
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
    table.insert(lines,'Auto-routed (available for renaming): '..(counts.auto_routed or 0))
    if settings_ref and obs.obs_data_get_bool(settings_ref,'show_options') then
        table.insert(lines,'Recent history:')
        for i=math.max(1,#history-7),#history do table.insert(lines,history[i]) end
    end
    return table.concat(lines,'\n')
end

local PAGE_SIZE=50
local clip_page,clip_pages=1,1
local previous_selection=''
local function selectable(item)
    return item.phase~='done' and item.phase~='moving'
end
local function reset_selection(s)
    previous_selection=''
    if s then
        obs.obs_data_set_string(s,'selected_clip','')
        obs.obs_data_set_string(s,'manual_exe','')
    end
end
local function old_auto(item,month)
    local m=(item.month or ''):match('^%d%d%d%d%-(%d%d)$')
    return item.phase=='auto_routed' and m and m>='01' and m<='12' and item.month<month
end
local function confirm_old()
    if not loaded then return end
    local rows,month,confirmed={},os.date('%Y-%m'),0
    for _,item in ipairs(queue) do
        if old_auto(item,month) then
            local copy={}
            for k,v in pairs(item) do copy[k]=v end
            copy.phase='done'; copy.routing=''
            table.insert(rows,copy)
            confirmed=confirmed+1
        else
            table.insert(rows,item)
        end
    end
    if confirmed==0 then return end
    trim_completed(rows)
    if not persist(rows) then return end
    for i=#queue,1,-1 do queue[i]=nil end
    for i,item in ipairs(rows) do queue[i]=item end
    note('Confirmed folders for '..confirmed..' older clips')
end

local function fill_selector(p,advanced)
    local page=obs.obs_properties_get(p,'clip_page')
    local archive=obs.obs_properties_get(p,'confirm_old')
    if not advanced then
        obs.obs_property_set_visible(page,false)
        obs.obs_property_set_visible(archive,false)
        return
    end
    local selector=obs.obs_properties_get(p,'selected_clip')
    local selected=settings_ref and obs.obs_data_get_string(settings_ref,'selected_clip') or ''
    local total,old,month,selected_ok=0,0,os.date('%Y-%m'),false
    for _,item in ipairs(queue) do
        if selectable(item) then
            total=total+1
            if item.src==selected then selected_ok=true end
        end
        if old_auto(item,month) then old=old+1 end
    end
    if selected~='' and not selected_ok then reset_selection(settings_ref) end
    clip_pages=math.max(1,math.ceil(total/PAGE_SIZE))
    clip_page=math.min(clip_page,clip_pages)
    local skip=(clip_page-1)*PAGE_SIZE
    obs.obs_property_list_clear(selector)
    obs.obs_property_list_add_string(selector,'Choose a clip','')
    local shown=0
    for i=#queue,1,-1 do
        local item=queue[i]
        if selectable(item) then
            if skip>0 then skip=skip-1
            else
                obs.obs_property_list_add_string(selector,get_filename_from_path(item.src)..' | '..item.exe,item.src)
                shown=shown+1
                if shown==PAGE_SIZE then break end
            end
        end
    end
    obs.obs_property_set_description(page,string.format('Clip page %d/%d — %s',clip_page,clip_pages,
        clip_page==clip_pages and 'Back to newest' or 'Show older clips'))
    obs.obs_property_set_visible(page,clip_pages>1)
    obs.obs_property_set_description(archive,'Finish tracking '..old..' auto-routed clips from previous months')
    obs.obs_property_set_visible(archive,old>0)
end

-- The editable list is a draft. Do not route a clip to a half-typed folder
-- or discard a game learned while the Scripts window was open.
local editor_base
local function sync_editor(s,force)
    if force or not editor_base or obs.obs_data_get_string(s,'game_rules_editor')==editor_base then
        editor_base=obs.obs_data_get_string(s,'game_rules_v2')
        obs.obs_data_set_string(s,'game_rules_editor',editor_base)
    end
end
local function apply_editor(s,exe,folder)
    local draft,err=parse_rules(obs.obs_data_get_string(s,'game_rules_editor'))
    if not draft then note(exe and ('Fix Game list first: '..err) or err); return false end
    local original=parse_rules(editor_base or '') or {}
    for name,learned_folder in pairs(learned) do
        if not original[name] and not draft[name] then draft[name]=learned_folder end
    end
    if exe then
        draft[exe]=folder
        learned[exe]=nil
    end
    obs.obs_data_set_string(s,'learned_games',rules_text(learned))
    obs.obs_data_set_string(s,'game_rules_v2',rules_text(draft))
    sync_editor(s,true)
    script_update(s)
    return true
end
local function refresh_ui(p)
    if settings_ref then sync_editor(settings_ref,false) end
    obs.obs_property_set_description(obs.obs_properties_get(p,'status_info'),report())
    fill_selector(p,settings_ref and obs.obs_data_get_bool(settings_ref,'show_options'))
    return true
end
function script_description()
    return '<h2>ReplayRoute 2.3.0</h2><p>Save a replay while Game Capture is capturing your game. Creates or reuses its folder and remembers the game.</p>'
end
function script_defaults(s)
    obs.obs_data_set_default_string(s,'destination_base_dir','D:\\Videos')
    obs.obs_data_set_default_string(s,'default_folder','Unclassified')
    obs.obs_data_set_default_bool(s,'subfolder_by_date',false)
    obs.obs_data_set_default_bool(s,'auto_start_replay_buffer',true)
    obs.obs_data_set_default_bool(s,'auto_create_game_folders',true)
    obs.obs_data_set_default_string(s,'game_rules_v2',default_rules)
end
function script_update(s)
    destination_base_dir=norm(obs.obs_data_get_string(s,'destination_base_dir'))
    default_folder=obs.obs_data_get_string(s,'default_folder')
    subfolder_by_date=obs.obs_data_get_bool(s,'subfolder_by_date')
    auto_start_replay_buffer=obs.obs_data_get_bool(s,'auto_start_replay_buffer')
    auto_create_game_folders=obs.obs_data_get_bool(s,'auto_create_game_folders')
    local parsed,err=parse_rules(obs.obs_data_get_string(s,'game_rules_v2'))
    config_error=err or ''
    if parsed then
        game_rules=parsed
        learned=parse_rules(obs.obs_data_get_string(s,'learned_games')) or {}
        for exe,folder in pairs(learned) do
            if game_rules[exe]~=folder then learned[exe]=nil end
        end
        obs.obs_data_set_string(s,'learned_games',rules_text(learned))
    end
    if not valid_base(destination_base_dir) or not safe_folder(default_folder) then config_error='Invalid folder: use an absolute local path and a single subfolder name' end
    if settings_ref~=s then
        if settings_ref then obs.obs_data_release(settings_ref) end
        settings_ref=s; obs.obs_data_addref(s)
    end
    if loaded and config_error=='' then schedule() end
end
local function extract_folder_name(raw)
    local s=(raw or ''):match('^%s*(.-)%s*$')
    if s=='' then return nil end
    local p=norm(s)
    local base=norm(destination_base_dir)
    if valid_base(base) then
        local prefix=base:lower()..(base:sub(-1)=='\\' and '' or '\\')
        if p:lower():sub(1,#prefix)==prefix then
            local rel=p:sub(#prefix+1)
            if rel~='' and not rel:find('\\') then s=rel end
        end
    end
    if safe_folder(s) then return s end
    return nil
end
local function set_tip(prop,text)
    if prop and obs.obs_property_set_long_description then obs.obs_property_set_long_description(prop,text) end
end
function script_properties()
    local p=obs.obs_properties_create()
    if settings_ref then sync_editor(settings_ref,false) end
    set_tip(obs.obs_properties_add_path(p,'destination_base_dir','Base folder',obs.OBS_PATH_DIRECTORY,nil,nil),
        'Local folder on the same drive and volume as your original clips.')
    obs.obs_properties_add_button(p,'refresh','Refresh status',refresh_ui)
    obs.obs_properties_add_text(p,'status_info',report(),obs.OBS_TEXT_INFO)
    local toggle=obs.obs_properties_add_bool(p,'show_options','Manage games and settings')
    set_tip(toggle,'Show game rules, clip reclassification, and advanced options.')
    set_tip(obs.obs_properties_add_text(p,'game_rules_editor','Game list',obs.OBS_TEXT_MULTILINE),
        'One rule per line: executable.exe = Folder. Click Apply game list and retry to save changes.')
    obs.obs_properties_add_button(p,'retry','Apply game list and retry',function(props)
        if settings_ref and apply_editor(settings_ref) then retry(); flush_ready(10) end
        return refresh_ui(props)
    end)
    local selection=obs.obs_properties_add_list(p,'selected_clip','Clip to reclassify',obs.OBS_COMBO_TYPE_LIST,obs.OBS_COMBO_FORMAT_STRING)
    set_tip(selection,'Select an unresolved or auto-routed clip to fill in its executable.')
    previous_selection=settings_ref and obs.obs_data_get_string(settings_ref,'selected_clip') or ''
    obs.obs_property_set_modified_callback(selection,function(_,_,s)
        local selected=obs.obs_data_get_string(s,'selected_clip')
        if selected==previous_selection then return false end
        previous_selection=selected
        local exe=''
        for _,item in ipairs(queue) do
            if item.src==selected and selectable(item) then exe=item.exe; break end
        end
        obs.obs_data_set_string(s,'manual_exe',exe)
        return true
    end)
    obs.obs_properties_add_button(p,'clip_page','Show older clips',function(props)
        clip_page=clip_page%clip_pages+1
        reset_selection(settings_ref)
        return refresh_ui(props)
    end)
    set_tip(obs.obs_properties_add_text(p,'manual_exe','Executable',obs.OBS_TEXT_DEFAULT),
        'Executable filename, for example newgame.exe.')
    set_tip(obs.obs_properties_add_text(p,'manual_folder','Folder',obs.OBS_TEXT_DEFAULT),
        'Folder name only (e.g. Rocket League), or a direct subfolder path inside Base folder.')
    obs.obs_properties_add_button(p,'classify_clip','Assign to selected clip',function(props)
        if not settings_ref then return false end
        local selected=obs.obs_data_get_string(settings_ref,'selected_clip')
        local folder=extract_folder_name(obs.obs_data_get_string(settings_ref,'manual_folder'))
        if not folder then note('Enter a folder name only (e.g. Rocket League), not an outside path'); return refresh_ui(props) end
        for _,item in ipairs(queue) do
            if item.src==selected and selectable(item) then
                item.folder=folder; item.routing=''; item.reason='Manual assignment'; item.phase='pending'; item.attempts=0; item.next=0
                reset_selection(settings_ref)
                if persist() then flush_ready(10) end
                return refresh_ui(props)
            end
        end
        note('Select a pending clip'); return refresh_ui(props)
    end)
    obs.obs_properties_add_button(p,'apply_rule','Save rule and reclassify',function(props)
        if not settings_ref then return false end
        local exe=obs.obs_data_get_string(settings_ref,'manual_exe'):lower():match('^%s*(.-)%s*$')
        local folder=extract_folder_name(obs.obs_data_get_string(settings_ref,'manual_folder'))
        if not executable(exe) or exe:find('=') or not folder then
            note('Enter an executable and a single folder name (e.g. Rocket League)'); return refresh_ui(props)
        end
        if apply_editor(settings_ref,exe,folder) then retry(); flush_ready(10) end
        return refresh_ui(props)
    end)
    local archive=obs.obs_properties_add_button(p,'confirm_old','Confirm older folders',function(props)
        confirm_old()
        return refresh_ui(props)
    end)
    set_tip(archive,'Stops tracking these auto-routed clips for future rule changes. Their files stay in the current folders.')
    set_tip(obs.obs_properties_add_text(p,'default_folder','Unclassified folder',obs.OBS_TEXT_DEFAULT),
        'Subfolder for ambiguous or unrecognized clips. Existing preference is preserved.')
    set_tip(obs.obs_properties_add_bool(p,'subfolder_by_date','Year-month subfolders'),
        'Place clips inside YYYY-MM subfolders within each game folder.')
    set_tip(obs.obs_properties_add_bool(p,'auto_start_replay_buffer','Auto-start Replay Buffer'),
        'Request Replay Buffer startup automatically after OBS finishes loading.')
    set_tip(obs.obs_properties_add_bool(p,'auto_create_game_folders','Auto-create game folders'),
        'Reuse matching folders or create new ones for unknown Game Capture games.')
    local optional={'default_folder','subfolder_by_date','auto_start_replay_buffer','auto_create_game_folders',
        'game_rules_editor','manual_exe','manual_folder','selected_clip','classify_clip','apply_rule','retry'}
    local function show_options(props,_,settings)
        local visible=settings and obs.obs_data_get_bool(settings,'show_options') or false
        for _,name in ipairs(optional) do
            obs.obs_property_set_visible(obs.obs_properties_get(props,name),visible)
        end
        fill_selector(props,visible)
        obs.obs_property_set_description(obs.obs_properties_get(props,'status_info'),report())
        return true
    end
    show_options(p,toggle,settings_ref)
    obs.obs_property_set_modified_callback(toggle,show_options)
    return p
end
function script_load(s)
    script_update(s)
    sync_editor(s,true)
    if not restore() then return end
    loaded=true
    note('ReplayRoute 2.3.0 loaded; queue restored')
    obs.obs_frontend_add_event_callback(on_event)
    local signals=obs.obs_get_signal_handler()
    obs.signal_handler_connect(signals,'source_activate',on_visibility_change)
    obs.signal_handler_connect(signals,'source_deactivate',on_visibility_change)
    obs.signal_handler_connect(signals,'source_update',on_visibility_change)
    request_sync()
    if persist() then schedule() end
    -- A manual reload occurs after FINISHED_LOADING and won't receive that event.
    local scene=obs.obs_frontend_get_current_scene()
    if scene then obs.obs_source_release(scene); obs.timer_add(start_buffer,1000) end
end
function script_save(s) if loaded then persist() end end
function script_unload()
    stop_queue_timer(); obs.timer_remove(start_buffer); obs.timer_remove(verify_buffer)
    if loaded then
        local signals=obs.obs_get_signal_handler()
        obs.signal_handler_disconnect(signals,'source_activate',on_visibility_change)
        obs.signal_handler_disconnect(signals,'source_deactivate',on_visibility_change)
        obs.signal_handler_disconnect(signals,'source_update',on_visibility_change)
    end
    obs.timer_remove(sync_visible)
    clear_watches()
    obs.obs_frontend_remove_event_callback(on_event)
    if loaded then persist() end
    loaded=false
    if settings_ref then obs.obs_data_release(settings_ref); settings_ref=nil end
end
-- Test-only exports: absent in normal OBS execution.
if rawget(_G,'OBS_ORGANIZER_TEST') then
    if type(OBS_ORGANIZER_TEST)=='table' then foreground=OBS_ORGANIZER_TEST.foreground or foreground end
    OBS_ORGANIZER_TEST={safe_folder=safe_folder,parse_rules=parse_rules,detect=detect,
        enqueue=enqueue,tick=process_queue,retry=retry,queue=queue,report=report,persist=persist,destination=destination,
        norm=norm,valid_base=valid_base,join=join}
end
