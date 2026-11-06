-- Replace persistence mocks with the actual installed libobs JSON implementation.
local ffi=require('ffi')
ffi.cdef[[
void* obs_data_create(void);
void obs_data_release(void*);
void obs_data_set_int(void*, const char*, long long);
long long obs_data_get_int(void*,const char*);
void obs_data_set_string(void*,const char*,const char*);
const char* obs_data_get_string(void*,const char*);
void* obs_data_array_create(void);
void obs_data_array_release(void*);
size_t obs_data_array_push_back(void*,void*);
size_t obs_data_array_count(void*);
void* obs_data_array_item(void*,size_t);
void obs_data_set_array(void*,const char*,void*);
void* obs_data_get_array(void*,const char*);
bool obs_data_save_json_safe(void*,const char*,const char*,const char*);
void* obs_data_create_from_json_file_safe(const char*,const char*);
]]
local lib=ffi.load(assert(os.getenv('OBS_BIN'))..'/obs.dll')
local fields={'src','dst','exe','folder','reason','phase','error','attempts','next','month','original'}
local function save(d,path)
 local native=lib.obs_data_create();lib.obs_data_set_int(native,'version',d.version)
 lib.obs_data_set_string(native,'history',d.history)
 local arr=lib.obs_data_array_create()
 for _,row in ipairs(d.queue) do
  local n=lib.obs_data_create()
  for _,f in ipairs(fields) do lib.obs_data_set_string(n,f,row[f]) end
  lib.obs_data_array_push_back(arr,n);lib.obs_data_release(n)
 end
 lib.obs_data_set_array(native,'queue',arr);lib.obs_data_array_release(arr)
 local ok=lib.obs_data_save_json_safe(native,path,'tmp','bak');lib.obs_data_release(native);return ok
end
local function load(path)
 local n=lib.obs_data_create_from_json_file_safe(path,'bak');if n==nil then return nil end
 local d={version=tonumber(lib.obs_data_get_int(n,'version')),history=ffi.string(lib.obs_data_get_string(n,'history')),queue={}}
 local arr=lib.obs_data_get_array(n,'queue')
 if arr~=nil then
  for i=0,tonumber(lib.obs_data_array_count(arr))-1 do
   local row=lib.obs_data_array_item(arr,i);local t={}
   for _,f in ipairs(fields) do t[f]=ffi.string(lib.obs_data_get_string(row,f)) end
   table.insert(d.queue,t);lib.obs_data_release(row)
  end
  lib.obs_data_array_release(arr)
 end
 lib.obs_data_release(n);return d
end
return {save=save,load=load}
