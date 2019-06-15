--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

ffi = require('ffi')
C = ffi.C
ffi.cdef[[
	typedef struct {
		uint8_t r;
		uint8_t g;
		uint8_t b;
	} color;
	typedef struct {
		float x;
		float y;
		float z;
	} vector;
	typedef struct {
		float yaw;
		float pitch;
	} angle;

	size_t fread(void* ptr, size_t size, size_t count, void* stream);
	size_t fwrite(const void* ptr, size_t size, size_t count, void* stream);
	int    ferror(void* stream);
]]

local ext = (jit.os == 'Windows'and'dll')or'so'
package.cpath = ('./bin/%s/?.%s;'):format(jit.arch, ext)
package.path = './lua/?.lua;./?.lua'

function checkEnv(ev, val)
	local evar = os.getenv(ev)
	if evar then
		return evar:lower():find(val:lower())
	else
		return false
	end
end

ENABLE_ANSI = checkEnv('ConEmuANSI', 'on')or checkEnv('TERM', 'xterm')or
checkEnv('TERM', 'screen')or checkEnv('TERM', 'linux')

lanes = require('lanes').configure{
	with_timers = false
}
struct = require('struct')

function packTo(file, fmt, ...)
	if select('#', ...) < 1 then return false end
	local data = struct.pack(fmt, ...)
	return file:write(data)
end

function unpackFrom(file, fmt)
	local sz = struct.size(fmt)
	local data = file:read(sz)
	return struct.unpack(fmt, data)
end

function writeString(f, v)
	assert(#v < 255, 'String too long')
	f:write(string.char(#v), v)
end

function readString(f)
	return f:read(f:read(1):byte())
end

function newColor(r, g, b)
	r, g, b = r or 255, g or 255, b or 255
	return ffi.new('color', r, g, b)
end

function newAngle(y, p)
	return ffi.new('angle', y, p)
end

function newVector(x, y, z)
	return ffi.new('vector', x, y, z)
end

function distance(x1, y1, z1, x2, y2, z2)
	return math.sqrt( (x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2 )
end

function toAngle(x, y)
	if y == 0 then
		if x < 0 then
			return 180
		elseif x > 0 then
			return 0
		else
			return 0
		end
	else
		angle = math.atan(y / x) / math.pi * 180

		if x < 0 then
			x = -x
			if y < 0 then
				angle = angle - 180
			else
				angle = angle + 180
			end
		end

		return angle
	end
end

floor = math.floor
ceil = math.ceil
bswap = bit.bswap

local colorReplace

if ENABLE_ANSI then
	local rt = {
		['&0'] = '30',
		['&1'] = '34',
		['&2'] = '32',
		['&3'] = '36',
		['&4'] = '31',
		['&5'] = '35',
		['&6'] = '33',
		['&7'] = '1;30',
		['&8'] = '1;30',
		['&9'] = '1;34',
		['&a'] = '1;32',
		['&b'] = '1;36',
		['&c'] = '1;31',
		['&d'] = '1;35',
		['&e'] = '1;33',
		['&f'] = '0'
	}
	colorReplace = function(s)
		s = s:lower()
		return string.format('\27[%sm', rt[s])
	end
else
	colorReplace = function()
		return ''
	end
end

function mc2ansi(str)
	local pattern = '(&%x)'
	if str:find(pattern)then
		str = str:gsub(pattern, colorReplace)
	end
	return str
end

function printf(...)
	local str = string.format(...)
	log.info(str)
	return str
end

function getn(t)
	local c = 0
	for _ in pairs(t)do c = c + 1 end
	return c
end

function getCurrentOnline()
	return SERVER_ONLINE or 0
end

local function woSpaces(...) -- It works faster than string.match
	local idx = 1
	local stStart, stEnd

	while true do
		local b = select(idx, ...)
		if not stStart then
			if b ~= 32 then
				stStart = idx
				idx = select('#', ...)
			else
				idx = idx + 1
			end
		else
			if b ~= 32 then
				stEnd = idx
				break
			end
			idx = idx - 1
			if idx == 1 then
				stEnd = 1
				break
			end
		end
	end

	return stStart, stEnd
end

function trimStr(str)
	return str:sub(woSpaces(str:byte(1, -1)))
end

function randomStr(len)
	local str = ffi.new('char[?]', len + 1)
	for i = 0, len - 1 do
		if math.random(0, 100) > 30 then
			str[i] = math.random(48, 57)
		else
			str[i] = math.random(97, 122)
		end
	end
	return ffi.string(str)
end

function getAddr(void)
	return tonumber(ffi.cast('uintptr_t', void))
end

function table.hasValue(tbl, ...)
	for i=1, #tbl do
		local idx = 1
		while true do
			local tv = select(idx, ...)
			if tv == nil then
				break
			end
			if tv == tbl[i]then
				return true
			end
			idx = idx + 1
		end
	end
	return false
end

function string.split(self, sep)
	local sep, fields = sep or ':', {}
	local pattern = string.format('([^%s]+)', sep)
	self:gsub(pattern, function(c) fields[#fields + 1] = c end)
	return fields
end

function string.startsWith(self, ...)
	local idx = 1
	while true do
		local str = select(idx, ...)
		if str == nil then
			break
		end
		if self:sub(1, #str) == str then
			return true, idx
		end
		idx = idx + 1
	end
	return false
end

if jit.os == 'Windows'then
	ffi.cdef[[
		typedef struct {
		  unsigned int dwLowDateTime;
		  unsigned int dwHighDateTime;
		} filetime;

		typedef struct {
			unsigned int dwFileAttributes;
			filetime  ftCreationTime;
			filetime  ftLastAccessTime;
			filetime  ftLastWriteTime;
			unsigned int     nFileSizeHigh;
			unsigned int     nFileSizeLow;
			unsigned int     dwReserved0;
			unsigned int     dwReserved1;
			char     cFileName[260];
			char     cAlternateFileName[14];
		} WIN32_FIND_DATA;

		void  GetSystemTimeAsFileTime(filetime*);
		void* FindFirstFileA(const char*, WIN32_FIND_DATA*);
		bool  FindNextFileA(void*, WIN32_FIND_DATA*);
		void  Sleep(unsigned int);
		bool  FindClose(void*);
	]]

	function gettime()
		local ft = ffi.new('filetime')
		C.GetSystemTimeAsFileTime(ft)
		local wtime = ft.dwLowDateTime / 1.0e7 + ft.dwHighDateTime * 429.4967296
		return wtime - 11644473600
	end

	function sleep(ms)
		C.Sleep(ms)
	end

	function scanDir(path, ext)
		local fdata = ffi.new('WIN32_FIND_DATA')
		local file

		local function getName()
			local name = ffi.string(fdata.cFileName)
			if #name > 0 then
				return name
			end
		end

		local function isFile()
			return bit.band(fdata.dwFileAttributes, 16) == 0
		end

		if not ext then
			ext = '*'
		end

		return function()
			if not file then
				file = C.FindFirstFileA(path .. '\\*.' .. ext, fdata)
				if file == ffi.cast('void*', -1)then
					return
				end
				return getName(), isFile()
			end

			if C.FindNextFileA(file, fdata)then
				return getName(), isFile()
			else
				C.FindClose(file)
			end
		end
	end
else
	ffi.cdef[[
		struct dirent {
			unsigned long  d_ino;
			unsigned long  d_off;
			unsigned short d_reclen;
			unsigned char  d_type;
			char           d_name[256];
		};

		struct timeval {
			long tv_sec;
			long tv_usec;
		};

		void  gettimeofday(struct timeval*, void*);
		void  usleep(unsigned int);
		void* opendir(const char*);
		struct dirent* readdir(void*);
	]]

	local function scanNext(dir, ext)
		while true do
			local _ent = C.readdir(dir)
			if _ent == nil then break end
			local name = ffi.string(_ent.d_name)
			if name:sub(-#ext) == ext then
				return name, _ent.d_type == 8
			end
		end
	end

	function sleep(ms)
		C.usleep(ms * 1000)
	end

	function gettime()
		local t = ffi.new('struct timeval')
		C.gettimeofday(t, nil)
		return tonumber(t.tv_sec) + 1e-6 * tonumber(t.tv_usec)
	end

	function scanDir(dir, ext)
		local _dir = C.opendir(dir)
		if _dir == nil then return end

		return function()
			return scanNext(_dir, ext)
		end
	end
end

function dirForEach(dir, ext, func)
	for name, isFile in scanDir(dir, ext)do
		if isFile then
			func(name, dir .. '/' .. name)
		end
	end
end

function makeNormalCube(p1, p2)
	local px1, py1, pz1 = unpack(p1)
	local px2, py2, pz2 = unpack(p2)

	if p1[1] - p2[1] < 0 then
		px1 = p2[1] + 1
		px2 = p1[1]
	else
		px1 = p1[1] + 1
	end
	if p1[2] - p2[2] < 0 then
		py1 = p2[2] + 1
		py2 = p1[2]
	else
		py1 = p1[2] + 1
	end
	if p1[3] - p2[3] < 0 then
		pz1 = p2[3] + 1
		pz2 = p1[3]
	else
		pz1 = p1[3] + 1
	end

	return px1, py1, pz1, px2, py2, pz2
end

function watchThreads(threads)
	while #threads > 0 do
		local thread = threads[#threads]
		if thread then
			if thread.status == 'error'then
				log.error(thread[-1])
				table.remove(threads, #threads)
			elseif thread.status == 'done'then
				table.remove(threads, #threads)
			end
		else
			sleep(40)
		end
	end
end

require('hooks')
dirForEach('lua', 'lua', function(file)
	require(file:sub(1, -5))
end)
