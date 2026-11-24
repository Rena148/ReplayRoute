-- Uses the actual Windows filesystem/Win32 FFI and OBS's installed LuaJIT DLL.
-- OBS UI/event functions are mocked; no real OBS or user clips are touched.
local root=assert(os.getenv('OBS_ROUTER_TEST_ROOT')):gsub('\\','/')
local scene={items={},name='Program',id='scene'}
local callbacks={}
local timers,core_signals={},{}
local now=100000000000
local outstanding,refs,sequence=0,0,0
local datafail=false
local native_json=dofile('tests/native_json_adapter.lua')
obslua={LOG_INFO=1,OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED=1,
 OBS_FRONTEND_EVENT_REPLAY_BUFFER_STARTED=2,OBS_FRONTEND_EVENT_REPLAY_BUFFER_STOPPED=3,
 OBS_FRONTEND_EVENT_SCENE_CHANGED=4,OBS_FRONTEND_EVENT_SCENE_COLLECTION_CHANGED=5,OBS_FRONTEND_EVENT_FINISHED_LOADING=6,
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
function o.timer_add(f,ms) timers[f]=ms end
function o.timer_remove(f) timers[f]=nil end
function o.os_gettime_ns() return now end
function o.blog(_,s) print(s) end
function o.obs_frontend_add_event_callback(f) callbacks[f]=true end
function o.obs_frontend_remove_event_callback(f) callbacks[f]=nil end
function o.obs_frontend_replay_buffer_active() return false end
function o.obs_frontend_replay_buffer_start() end
function o.obs_source_get_ref(s) refs=refs+1;return s end
function o.obs_frontend_get_current_scene() return scene and o.obs_source_get_ref(scene) end
function o.obs_scene_from_source(s) return s end
function o.obs_scene_enum_items(s) return s.items end
function o.obs_sceneitem_visible(i) return i.visible~=false end
function o.obs_sceneitem_get_source(i) return i end
function o.obs_source_get_name(s) return s.name end
function o.obs_source_get_uuid(s)
 if not s.uuid then sequence=sequence+1;s.uuid=tostring(sequence) end
 return s.uuid
end
function o.obs_source_get_id(s) return s.id end
function o.obs_source_get_settings(s) return s.settings end
function o.obs_sceneitem_is_group(s) return s.id=='group' end
function o.obs_sceneitem_group_get_scene(s) return s end
function o.obs_source_release() refs=refs-1;assert(refs>=0) end
function o.obs_source_get_proc_handler(s) return s end
function o.calldata_create() outstanding=outstanding+1;return {} end
function o.calldata_destroy() outstanding=outstanding-1;assert(outstanding>=0) end
function o.proc_handler_call(s,name,data)
 assert(name=='get_hooked')
 if s.unsupported then return false end
 data.hooked=s.hooked or false;data.executable=s.hook_exe;return true
end
o.calldata_string=o.obs_data_get_string
o.calldata_bool=o.obs_data_get_bool
function o.calldata_source(d,k) return d[k] end
function o.obs_get_signal_handler() return core_signals end
function o.obs_source_get_signal_handler(s) s.signals=s.signals or {};return s.signals end
function o.signal_handler_connect(h,n,cb) assert(not h[n],n);h[n]=cb end
function o.signal_handler_disconnect(h,n,cb) assert(h[n]==cb,n);h[n]=nil end
function o.sceneitem_list_release() end
function o.obs_properties_create() return {} end
function o.obs_properties_add_text(p,k,label) local x={description=label};p[k]=x;return x end
o.obs_properties_add_path=o.obs_properties_add_text
o.obs_properties_add_bool=o.obs_properties_add_text
function o.obs_property_set_visible(p,visible) p.visible=visible end
function o.obs_property_set_modified_callback(p,cb) p.modified=cb end
function o.obs_properties_add_list(p,k) local x={values={}};p[k]=x;return x end
function o.obs_property_list_add_string(p,_,value) table.insert(p.values,value) end
function o.obs_properties_get(p,k) return p[k] end
function o.obs_property_set_description(p,s) p.description=s end
function o.obs_property_list_clear(p) p.values={} end
function o.obs_property_set_long_description(p,s) p.help=s end
function o.obs_properties_add_button(p,k,label,cb)
 local button=setmetatable({description=label},{__call=function(_,props) return cb(props) end})
 p[k]=button;return button
end
function script_path() return root..'/' end
local script='obs_replay_organizer.lua'
local focused='test-desktop.exe'
local function load_router()
 OBS_ORGANIZER_TEST={foreground=function() return focused end}
 assert(loadfile(script))()
end
load_router()
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
load_router(); script_load(settings); t=OBS_ORGANIZER_TEST
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
load_router();script_load(settings);t=OBS_ORGANIZER_TEST
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
script_unload();load_router();script_load(settings);t=OBS_ORGANIZER_TEST
auto_item=t.queue[#t.queue];assert(auto_item.routing=='auto' and auto_item.phase=='auto_routed')
assert(settings.game_rules_v2:find('brandnew.exe = brandnew',1,true))
settings.game_rules_v2=settings.game_rules_v2:gsub('brandnew%.exe = brandnew','brandnew.exe = Brand New Game')
script_update(settings);t.retry();tick_all()
assert(auto_item.phase=='done' and auto_item.routing=='' and auto_item.src:find('Brand New Game',1,true))
assert(k.GetFileAttributesW(wide(root..'/dest/brandnew'))==4294967295,'empty auto-created folder was not pruned')
-- Existing folders are reused by normalized name, and technical suffixes are stripped.
os.execute('mkdir "'..root..'\\dest\\Dead by Daylight" 2>nul')
os.execute('mkdir "'..root..'\\dest\\Dual Match" 2>nul')
os.execute('mkdir "'..root..'\\dest\\dualmatch" 2>nul')
scene.items={capture('DeadByDaylight-Win64-Shipping.exe')}
detected,auto_folder,_,routing=t.detect()
assert(detected=='deadbydaylight-win64-shipping.exe' and auto_folder=='Dead by Daylight' and routing=='auto')
scene.items={capture('DualMatch.exe')}
detected,auto_folder,_,routing=t.detect()
assert(auto_folder=='dualmatch' and routing=='auto','ambiguous existing folders should not pick arbitrarily')
scene.items={capture('Unclassified.exe')}
detected,auto_folder,_,routing=t.detect()
assert(auto_folder=='unclassified','default folder must not be matched as a game folder')
scene.items={capture('FreshTitle-Win64-Shipping.exe')}
detected,auto_folder,_,routing=t.detect()
assert(auto_folder=='freshtitle' and routing=='auto')
scene.items={capture('AnotherGame_DX12.exe')}
detected,auto_folder,_,routing=t.detect()
assert(auto_folder=='anothergame' and routing=='auto')
scene.items={capture('brandnew.exe')}
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

-- Validate root handling without writing to a real drive root. Exercise a
-- dot-prefixed base with a real move under the temporary directory.
assert(t.norm('D:/')=='D:\\' and t.valid_base(t.norm('D:/')))
assert(t.norm('D://Videos///Clips/')=='D:\\Videos\\Clips' and t.norm('//server/share//sub/')=='\\\\server\\share\\sub')
assert(t.join(t.norm('D:/'),'Game')=='D:\\Game')
assert(t.valid_base(t.norm('D:/.clips/')) and not t.valid_base('D:'))
for _,path in ipairs({'D:/a/../b','D:/a/.','//server/share','D:/CON/Clips','D:/NUL'}) do assert(not t.valid_base(t.norm(path)),path) end
settings.destination_base_dir=root..'/.clips'
settings.auto_create_game_folders=true
script_update(settings)
props=script_properties()
-- Leave the editor open while a new game is learned. Typing a partial rename
-- must not reroute an existing clip or overwrite a concurrently learned rule.
local before=settings.game_rules_editor
settings.game_rules_editor=before..'\nextra.exe = Par'
script_update(settings)
local game=capture('stale.exe','Fullscreen')
game.settings.capture_mode='any_fullscreen'
game.hooked=true;game.hook_exe='C:\\Games\\UNSEEN.EXE'
local ignored=capture('different.exe');ignored.visible=false
scene.items={{name='Nested',id='scene',items={{name='Group',id='group',items={game,ignored}}}}}
local last_path=write('fullscreen.mp4','first full-screen replay')
function o.obs_frontend_get_last_replay() return last_path end
local function event(kind) for f in pairs(callbacks) do f(kind) end end
event(o.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED)
tick_all()
local first=t.queue[#t.queue]
assert(first.exe=='unseen.exe' and first.phase=='auto_routed' and read(first.src)=='first full-screen replay')
assert(first.src:find('\\.clips\\unseen\\',1,true) and settings.game_rules_v2:find('unseen.exe = unseen',1,true))
assert(not settings.game_rules_v2:find('extra.exe',1,true),'draft applied during typing')
settings.game_rules_editor=before..'\nextra.exe = '
settings.manual_exe='manualcheck.exe';settings.manual_folder='Manual Check'
props.apply_rule(props)
assert(t.report():find('Fix Game list first:',1,true))
assert(not settings.game_rules_v2:find('manualcheck.exe',1,true) and not settings.game_rules_v2:find('extra.exe',1,true),'invalid draft committed')
settings.manual_exe='';settings.manual_folder=''
settings.game_rules_editor=before..'\nextra.exe = Example'
props.retry(props);tick_all()
assert(settings.game_rules_v2:find('unseen.exe = unseen',1,true),'lost new game while editing')
settings.game_rules_editor=settings.game_rules_editor:gsub('unseen%.exe = unseen','unseen.exe = Real Name')
script_update(settings);tick_all();assert(first.phase=='auto_routed')
props.retry(props);tick_all()
assert(first.phase=='done' and first.src:find('\\Real Name\\',1,true) and read(first.src)=='first full-screen replay')

-- Native process enumeration: the test host really is running; the synthetic
-- game below isn't. Simulated hook/loss signals arrive before any save.
ffi.cdef[[DWORD GetModuleFileNameA(void*,char*,DWORD);]]
local pathbuf=ffi.new('char[32768]')
assert(k.GetModuleFileNameA(nil,pathbuf,32768)>0)
local runner=ffi.string(pathbuf):match('([^\\/]+)$'):lower()
local function fire_sync()
 for f,ms in pairs(timers) do if ms==50 then f(); return end end
 error('expected a scene sync')
end
local function emit_hook(s,name)
 s.hooked=true;s.hook_exe=name
 s.signals.hooked({executable=name})
end
local function emit_loss(s)
 s.hooked=false;s.hook_exe=nil
 s.signals.unhooked({})
end
local full=capture('unused.exe','New fullscreen source')
full.settings.capture_mode='any_fullscreen'
scene.items={full}
core_signals.source_activate({source=full});fire_sync()
emit_hook(full,runner);now=now+600000000000;emit_loss(full)
now=now+40000000000
detected,auto_folder,_,routing=t.detect()
assert(detected==runner and auto_folder and routing=='auto','first Alt-Tab clip missed')
now=now+6000000000
assert(select(2,t.detect())==nil,'reuse extended the grace period')
emit_hook(full,'replayroute-nonexistent-proc-9137.exe');emit_loss(full)
assert(select(2,t.detect())==nil,'a closed game survived the process check')
emit_hook(full,runner);emit_loss(full)
scene={name='Other scene',id='scene',items={full}}
event(o.OBS_FRONTEND_EVENT_SCENE_CHANGED);fire_sync()
assert(select(2,t.detect())==nil,'different scene inherited a previous hook')
emit_hook(full,runner);emit_loss(full)
full.visible=false;core_signals.source_deactivate({source=full});fire_sync()
assert(not full.signals.hooked and select(2,t.detect())==nil,'hidden source still tracked')
full.visible=true;core_signals.source_activate({source=full});fire_sync()
assert(select(2,t.detect())==nil,'re-enabled source inherited grace')

-- Default game list keeps only Deadlock; test rules below opt into CS2 and Valorant explicitly.
scene.items={};focused='project8.exe';assert(select(2,t.detect())=='Deadlock')
focused='helldivers2.exe';assert(select(2,t.detect())==nil,'only Deadlock should be bundled by default')
focused='test-desktop.exe'
settings.manual_exe='cs2.exe';settings.manual_folder='CS2';props.apply_rule(props)
settings.manual_exe='valorant.exe';settings.manual_folder='Valorant';props.apply_rule(props)
settings.manual_exe='';settings.manual_folder=''

local win={name='Window',id='window_capture',hooked=true,hook_exe='discord.exe'}
scene.items={win};focused='valorant.exe'
assert(select(2,t.detect())==nil,'a browser capture learned an unrelated foreground game')
focused='test-desktop.exe'
win.hook_exe='C:/Games/CS2.EXE';detected,auto_folder=t.detect()
assert(detected=='cs2.exe' and auto_folder=='CS2')
full.hooked=true;full.hook_exe='other.exe';scene.items={full,win}
detected,auto_folder=t.detect();assert(detected=='' and not auto_folder,'two live games guessed')
full.hook_exe='cs2.exe';assert(select(2,t.detect())=='CS2','two views of one game conflicted')
full.hook_exe='';assert(select(2,t.detect())==nil,'unknown live hook was ignored')
scene.items={full};full.hook_exe='optedout.exe'
settings.auto_create_game_folders=false;script_update(settings)
detected,auto_folder=t.detect();assert(detected=='optedout.exe' and not auto_folder)
settings.auto_create_game_folders=true;script_update(settings)
full.hooked=false;full.unsupported=true;full.settings.capture_mode='window';scene.items={full}
assert(t.detect()=='unused.exe','configured fallback unavailable on older source')
focused='valorant.exe';assert(select(2,t.detect())==nil,'conflicting weak capture and foreground')
scene.items={};assert(select(2,t.detect())=='Valorant');focused='test-desktop.exe'

-- The selector suggests an executable but lets the user clear or edit it.
settings.show_options=true;script_update(settings);props=script_properties()
local function select_clip(path)
 settings.selected_clip=path
 props.selected_clip.modified(props,props.selected_clip,settings)
end
local manual={src=write('unmoved.mp4','manual clip'),exe='example.exe',phase='unclassified',month='2000-01',attempts=0}
local reclass={src=write('reclass.mp4','reclassify me'),exe='reclass.exe',phase='unclassified',month='2000-01',attempts=0}
table.insert(t.queue,manual);table.insert(t.queue,reclass)
select_clip(manual.src);assert(settings.manual_exe=='example.exe')
select_clip('');assert(settings.manual_exe=='')
-- Old auto-routed receipts are archived only on request, after a successful
-- queue write. User files, current-month clips and unresolved cases survive.
for i=1,56 do
 table.insert(t.queue,{src=write('older'..i..'.mp4','old clip '..i),exe='example.exe',phase='auto_routed',month='2000-01',routing='auto'})
end
local keep_file=write('archive.mp4','already saved')
local old={src=keep_file,exe='old.exe',phase='auto_routed',month='2000-01',routing='auto'}
local current={src=write('current.mp4','current clip'),exe='current.exe',phase='auto_routed',month=os.date('%Y-%m'),routing='auto'}
table.insert(t.queue,old);table.insert(t.queue,current)
props.refresh(props);assert(#props.selected_clip.values==51 and props.clip_page.visible and props.confirm_old.visible)
local newest=props.selected_clip.values[2];props.clip_page(props);assert(props.selected_clip.values[2]~=newest)
props.clip_page(props);assert(props.selected_clip.values[2]==newest)
-- Paging must reset selection state so re-selecting the same clip refills manual_exe.
select_clip(reclass.src);assert(settings.manual_exe=='reclass.exe')
props.clip_page(props);assert(settings.selected_clip=='' and settings.manual_exe=='')
props.clip_page(props);select_clip(reclass.src);assert(settings.manual_exe=='reclass.exe','stale previous_selection blocked refill')
settings.manual_folder=root..'/.clips/Manual Reassigned';props.classify_clip(props)
assert(settings.selected_clip=='' and settings.manual_exe=='','classify_clip did not clear selection')
assert(reclass.phase=='done' and reclass.src:find('Manual Reassigned',1,true),'classify_clip should move and refresh immediately')
for _,v in ipairs(props.selected_clip.values) do assert(v~=reclass.src,'moved clip stayed in selector') end
assert(props.status_info.description:find('Saved:',1,true))
settings.manual_folder=''
-- Reject an outside path passed to Folder without modifying rules.
settings.manual_exe='badpath.exe';settings.manual_folder='C:\\Outside\\Folder'
props.apply_rule(props);assert(not settings.game_rules_v2:find('badpath.exe',1,true))
settings.manual_exe='';settings.manual_folder=''
-- Confirming old auto-routed clips clears a stale selection and preserves files.
select_clip(old.src);assert(settings.manual_exe=='old.exe')
datafail=true;props.confirm_old(props);datafail=false
assert(old.phase=='auto_routed' and read(keep_file)=='already saved')
props.confirm_old(props)
assert(settings.selected_clip=='' and settings.manual_exe=='','stale selection survived archive')
assert(not props.confirm_old.visible and not props.clip_page.visible and read(keep_file)=='already saved')
local saved=native_json.load(root..'/obs_organizer_state.json')
local by_path={};for _,row in ipairs(saved.queue) do by_path[row.src]=row.phase end
assert(by_path[keep_file]=='done' and by_path[current.src]=='auto_routed' and by_path[manual.src]=='unclassified')
-- Deleting clips from disk prunes unclassified/auto_routed entries on refresh when Base folder exists.
os.remove(manual.src);os.remove(current.src)
local missing_blocked={src=root..'/missing_blocked.mp4',exe='blocked.exe',phase='blocked',attempts=8,month='2000-01'}
table.insert(t.queue,missing_blocked)
props.refresh(props)
local has_val={}
for _,v in ipairs(props.selected_clip.values) do has_val[v]=true end
assert(not has_val[manual.src] and not has_val[current.src],'deleted clips stayed in selector')
assert(has_val[missing_blocked.src],'missing blocked clip should stay selectable')
assert(props.status_info.description:find('Unclassified: 0',1,true) and props.status_info.description:find('Auto-routed (available for renaming): 0',1,true))
local saved_after=native_json.load(root..'/obs_organizer_state.json')
local kept_blocked=false
for _,row in ipairs(saved_after.queue) do
 assert(row.src~=manual.src and row.src~=current.src,'deleted clip stayed persisted')
 if row.src==missing_blocked.src and row.phase=='blocked' then kept_blocked=true end
end
assert(kept_blocked,'missing blocked clip should be preserved for manual inspection')
table.remove(t.queue)
-- Do not prune when Base folder itself is missing (disconnected drive protection).
local gone_clip=write('gone_drive.mp4','pending check')
table.insert(t.queue,{src=gone_clip,exe='deadlock.exe',phase='auto_routed',month=os.date('%Y-%m'),routing='auto'})
os.remove(gone_clip)
local prev_base=settings.destination_base_dir
settings.destination_base_dir=root..'/unmounted_drive';script_update(settings)
props.refresh(props)
local still_queued=false;for _,v in ipairs(props.selected_clip.values) do if v==gone_clip then still_queued=true end end
assert(still_queued,'clips should not be pruned when Base folder is missing')
settings.destination_base_dir=prev_base;script_update(settings)
props.refresh(props)
for _,v in ipairs(props.selected_clip.values) do assert(v~=gone_clip,'deleted clip was not pruned once Base folder returned') end
-- Rapid same-second replay saves enqueue immediately with 200ms timer and deduplicate safely.
scene.items={full};full.unsupported=nil;full.hooked=true;full.hook_exe='cs2.exe'
local rapid1=write('rapid.mp4','first rapid');t.enqueue(rapid1)
assert(t.queue[#t.queue].next==0 and timers[t.tick]==200)
tick_all()
local rapid2=write('rapid.mp4','second rapid');t.enqueue(rapid2);tick_all()
assert(read(t.queue[#t.queue-1].src)=='first rapid' and read(t.queue[#t.queue].src)=='second rapid')
assert(t.queue[#t.queue].src:find(' (1)',1,true))

settings.game_rules_v2='invalid';script_update(settings)
p=write('invalid.mp4','keep');t.enqueue(p);tick_all();assert(read(p)=='keep')
script_unload()
assert(refs==0 and outstanding==0 and not next(core_signals) and not next(timers),'OBS resource leak')
print('PASS: hook routing, Alt-Tab, scene isolation, rules, paths, paging, archive, recovery and non-overwriting moves')
