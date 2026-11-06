-- Uses the actual Windows filesystem/Win32 FFI and OBS's installed LuaJIT DLL.
-- OBS UI/event functions are mocked; no real OBS or user clips are touched.
local root=assert(os.getenv('OBS_ROUTER_TEST_ROOT')):gsub('\\','/')
local scene={items={}}
local callbacks={}
local datafail=false
local native_json=dofile('tests/native_json_adapter.lua')
obslua={LOG_INFO=1,OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED=1,
 OBS_FRONTEND_EVENT_REPLAY_BUFFER_STARTED=2,OBS_FRONTEND_EVENT_REPLAY_BUFFER_STOPPED=3,
 OBS_TEXT_INFO=3,OBS_TEXT_DEFAULT=0,OBS_TEXT_MULTILINE=1,OBS_PATH_DIRECTORY=2,
 OBS_COMBO_TYPE_LIST=1,OBS_COMBO_FORMAT_STRING=1}
local o=obslua
function o.obs_data_create() return {} end
function o.obs_data_set_int(d,k,v) d[k]=v end
o.obs_data_set_string=o.obs_data_set_int; o.obs_data_set_bool=o.obs_data_set_int
function o.obs_data_get_string(d,k) return d[k] or '' end
function o.obs_data_get_int(d,k) return d[k] or 0 end
function o.obs_data_get_bool(d,k) return d[k] or false end
function o.obs_data_set_default_string(d,k,v) if d[k]==nil then d[k]=v end end
o.obs_data_set_default_bool=o.obs_data_set_default_string
function o.obs_data_release() end
function o.obs_data_addref() end
function o.obs_data_array_create() return {} end
function o.obs_data_array_push_back(a,x) table.insert(a,x) end
function o.obs_data_array_count(a) return #a end
function o.obs_data_array_item(a,i) return a[i+1] end
function o.obs_data_array_release() end
function o.obs_data_set_array(d,k,v) d[k]=v end
function o.obs_data_get_array(d,k) return d[k] end
function o.obs_data_save_json_safe(d,path)
 if datafail then return false end
 return native_json.save(d,path)
end
function o.obs_data_create_from_json_file_safe(path) return native_json.load(path) end
function o.timer_add() end
function o.timer_remove() end
function o.blog(_,s) print(s) end
function o.obs_frontend_add_event_callback(f) callbacks[f]=true end
function o.obs_frontend_remove_event_callback(f) callbacks[f]=nil end
function o.obs_frontend_replay_buffer_active() return false end
function o.obs_frontend_replay_buffer_start() end
function o.obs_frontend_get_current_scene() return scene end
function o.obs_scene_from_source(s) return s end
function o.obs_scene_enum_items(s) return s.items end
function o.obs_sceneitem_visible(i) return i.visible~=false end
function o.obs_sceneitem_get_source(i) return i end
function o.obs_source_get_name(s) return s.name end
function o.obs_source_get_id(s) return s.id end
function o.obs_source_get_settings(s) return s.settings end
function o.obs_sceneitem_is_group() return false end
function o.obs_source_release() end
function o.sceneitem_list_release() end
function o.obs_properties_create() return {} end
function o.obs_properties_add_path() end
function o.obs_properties_add_text(p,k,label) local x={description=label};p[k]=x;return x end
function o.obs_properties_add_bool() end
function o.obs_properties_add_list(p,k) local x={};p[k]=x;return x end
function o.obs_property_list_add_string() end
function o.obs_properties_get(p,k) return p[k] end
function o.obs_property_set_description(p,s) p.description=s end
function o.obs_property_list_clear() end
function o.obs_properties_add_button(p,k,label,cb) p[k]=cb end
function script_path() return root..'/' end
local script='obs_replay_organizer.lua'
OBS_ORGANIZER_TEST=true
assert(loadfile(script))()
local settings={}; script_defaults(settings)
settings.destination_base_dir=root..'/dest'
settings.auto_start_replay_buffer=false
assert(settings.auto_create_game_folders==true,'automatic folders should default to enabled')
settings.auto_create_game_folders=false
script_load(settings)
local t=OBS_ORGANIZER_TEST
assert(not t.safe_folder('..') and not t.safe_folder('CON.txt') and t.safe_folder('GTA 6'))
assert(not t.parse_rules('abc.exe = ../unsafe'))
assert(not t.parse_rules('abc.exe = A\nabc.exe = B'))
local function capture(exe,name)
 return {name=name or exe,id='game_capture',settings={capture_mode='window',window='title:class:'..exe}}
end
scene.items={capture('newgame.exe')}
local exe,folder=t.detect(); assert(exe=='newgame.exe' and folder==nil)
scene.items={capture('a.exe'),capture('b.exe')}; exe,folder=t.detect(); assert(exe=='' and folder==nil)
scene.items={capture('newgame.exe')}
local function write(name,content)
 local p=root..'/'..name; local f=assert(io.open(p,'wb')); f:write(content); f:close(); return p
end
local function read(p) local f=io.open(p,'rb'); if not f then return nil end; local s=f:read('*a');f:close();return s end
local function tick_all()
 for n=1,20 do for _,q in ipairs(t.queue) do q.next=0 end; t.tick() end
end
local p=write('one.mp4','original')
t.enqueue(p); t.enqueue(p); assert(#t.queue==1,'duplicate enqueue')
tick_all(); assert(t.queue[1].phase=='unclassified' and read(t.queue[1].src)=='original')
settings.game_rules_v2=settings.game_rules_v2..'\nnewgame.exe = New Game'
script_update(settings); t.retry(); tick_all()
assert(t.queue[1].phase=='done' and t.queue[1].src:find('New Game',1,true))
-- Existing destination must survive; actual Windows rename flags tested.
p=write('one.mp4','second')
-- Same original path is deliberately deduplicated; use a second input directory.
os.execute('mkdir "'..root..'/input2" 2>nul')
p=write('input2/one.mp4','second');t.enqueue(p); tick_all()
assert(read(t.queue[1].src)=='original','overwrote existing destination')
assert(t.queue[2].src:find(' (1)',1,true) and read(t.queue[2].src)=='second')
-- Durable queue restored on reload, callbacks released.
p=write('recover.mp4','recover');t.enqueue(p)
script_unload(); assert(next(callbacks)==nil)
OBS_ORGANIZER_TEST=true; assert(loadfile(script))(); script_load(settings); t=OBS_ORGANIZER_TEST
tick_all(); assert(t.queue[3].phase=='done' and read(t.queue[3].src)=='recover')
-- Missing source gets blocked, not retried forever.
p=root..'/missing.mp4';t.enqueue(p);tick_all();assert(t.queue[4].phase=='blocked')
-- Failure to persist must leave source untouched.
p=write('storage.mp4','keep');datafail=true;t.enqueue(p);tick_all();assert(read(p)=='keep')
datafail=false;t.retry();tick_all();assert(t.queue[5].phase=='done')
-- UI fields/buttons exist and malformed rules stop processing.
local props=script_properties(); assert(props.apply_rule and props.classify_clip and props.retry and props.refresh)
props.refresh(props); assert(props.status_info.description:find('Replay Buffer',1,true))
-- Real Win32 exclusive lock: retries stop after six attempts, original survives.
local ffi=require('ffi')
ffi.cdef[[ void* CreateFileW(const wchar_t*, unsigned long, unsigned long, void*, unsigned long, unsigned long, void*); ]]
local k=ffi.load('kernel32')
local function wide(s)
 local n=k.MultiByteToWideChar(65001,0,s,-1,nil,0);local b=ffi.new('wchar_t[?]',n)
 k.MultiByteToWideChar(65001,0,s,-1,b,n);return b
end
p=write('locked.mp4','locked')
local handle=k.CreateFileW(wide(p),0x80000000,0,nil,3,0,nil)
assert(handle~=ffi.cast('void*',-1))
t.enqueue(p);tick_all();assert(t.queue[6].phase=='blocked' and t.queue[6].attempts==6 and read(p)==nil)
k.CloseHandle(handle);assert(read(p)=='locked');t.retry();tick_all();assert(t.queue[6].phase=='done')
-- Correct a clip manually without an executable rule.
scene.items={capture('a.exe'),capture('b.exe')}
p=write('ambiguous.mp4','manual');t.enqueue(p);tick_all()
assert(t.queue[7].phase=='unclassified')
settings.selected_clip=t.queue[7].src;settings.manual_folder='Manual'
props.classify_clip(props);tick_all();assert(t.queue[7].phase=='done' and t.queue[7].src:find('Manual',1,true))
-- A new recording can reuse a previous original name after the old one moved.
scene.items={capture('newgame.exe')}
p=write('recover.mp4','new recording');t.enqueue(p);tick_all()
assert(#t.queue==8 and read(t.queue[8].src)=='new recording')
-- Cross-drive requests must be blocked without copying/deleting the source.
settings.destination_base_dir=(root:sub(1,1):upper()=='C' and 'D:/Videos' or 'C:/Videos');script_update(settings)
p=write('cross.mp4','cross');t.enqueue(p);tick_all();assert(t.queue[9].phase=='blocked' and read(p)=='cross')
settings.destination_base_dir=root..'/dest';script_update(settings)
-- Simulate power loss after rename but before journal completion.
p=write('interrupted.mp4','journal');t.enqueue(p)
local item=t.queue[10];item.dst=assert(t.destination(item));item.phase='moving';assert(t.persist())
assert(os.rename(item.src,item.dst));script_unload()
OBS_ORGANIZER_TEST=true;assert(loadfile(script))();script_load(settings);t=OBS_ORGANIZER_TEST
tick_all();assert(t.queue[10].phase=='done' and read(t.queue[10].src)=='journal')
-- Automatic folders require an unambiguous specific Game Capture target.
settings.auto_create_game_folders=true;script_update(settings)
scene.items={capture('brandnew.exe')}
local detected,auto_folder,_,routing=t.detect()
assert(detected=='brandnew.exe' and auto_folder=='brandnew' and routing=='auto')
p=write('automatic.mp4','automatic');t.enqueue(p);tick_all()
local auto_item=t.queue[#t.queue]
assert(auto_item.phase=='auto_routed' and read(auto_item.src)=='automatic')
assert(auto_item.src:find('brandnew',1,true))
-- Persist and reload the auto-origin marker, then apply a readable rule.
script_unload();OBS_ORGANIZER_TEST=true;assert(loadfile(script))();script_load(settings);t=OBS_ORGANIZER_TEST
auto_item=t.queue[#t.queue];assert(auto_item.routing=='auto' and auto_item.phase=='auto_routed')
settings.game_rules_v2=settings.game_rules_v2..'\nbrandnew.exe = Brand New Game'
script_update(settings);t.retry();tick_all()
assert(auto_item.phase=='done' and auto_item.routing=='' and auto_item.src:find('Brand New Game',1,true))
detected,auto_folder,_,routing=t.detect();assert(auto_folder=='Brand New Game' and routing==nil,'explicit rule wins')
scene.items={capture('unknown1.exe'),capture('unknown2.exe')}
detected,auto_folder,_,routing=t.detect();assert(auto_folder==nil and routing==nil)
for _,unsafe in ipairs({'con.exe','nul.exe','.exe','../bad.exe'}) do
 scene.items={capture(unsafe)}
 detected,auto_folder,_,routing=t.detect();assert(auto_folder==nil and routing==nil,unsafe)
end
scene.items={capture('fullscreen.exe')};scene.items[1].settings.capture_mode='any_fullscreen'
detected,auto_folder,_,routing=t.detect();assert(routing~='auto')
settings.auto_create_game_folders=false;script_update(settings)
scene.items={capture('disabled.exe')}
detected,auto_folder,_,routing=t.detect();assert(auto_folder==nil and routing==nil)
settings.game_rules_v2='invalid';script_update(settings)
p=write('invalid.mp4','keep');t.enqueue(p);tick_all();assert(read(p)=='keep')
script_unload()
print('PASS: recovery, collision safety, retries, auto-routing, option disabled, explicit rule priority, safe names, ambiguity, persisted auto-routing and reclassification')
