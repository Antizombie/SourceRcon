local timer = require('timer')
local p = require('utils').prettyPrint
local Buffer = require("buffer").Buffer
local uv = require('uv')
local core = require('core')

local SERVERDATA_AUTH = 3
local SERVERDATA_EXECCOMMAND = 2
local SERVERDATA_AUTH_RESPONSE = 2
local SERVERDATA_RESPONSE_VALUE = 0

local Object = core.Object

local SourceRcon = {} -- Таблица передаваемая через require()
local ServersPasswd = {} -- Таблица с паролями, должна быть только тут. (приватной)

local function CreatePackage(body, Type) --Подготовка пакета
	Type = type(Type) == 'number' and Type or SERVERDATA_EXECCOMMAND
	local id = math.random(4294967295)
    local PackageSize = #body + 10
    local nilstart = "\00\00\00\00\00\00\00\00\00\00\00\00"
    local nilend = "\00\00"

    local PreCreatePackage = nilstart..body..nilend

    local buffer = Buffer:new(PreCreatePackage)
    buffer:writeUInt32LE(1, PackageSize)
    buffer:writeUInt32LE(5, id)
    buffer:writeUInt32LE(9, Type)

    id = buffer:readUInt32LE(5)

    return id, buffer:toString()
end

local function ParsingPackage( data ) --Разбор пакета
	local buffer = Buffer:new(data)
	local size = #data
	local PackageSize = buffer:readUInt32LE(1)
	local id, Type
	if (size - PackageSize) == 4 then
		id = buffer:readUInt32LE(5)
		Type = buffer:readUInt32LE(9)
	else
		print("ВНИМАНИЕ размер пакета не верный. Должен быть указан: "..(size - 4).." А указан: "..PackageSize)
		return nil
	end

	local String

	if size > 14 then
		String = buffer:toString(13, size - 2)
	else
		String = nil
	end

	return String, Type, id 
end

local sourcercon = {}

local SourceRcon = Object:extend()
sourcercon.SourceRcon = SourceRcon

local function ConnectedServer( table, Bool )
	if Bool then
		table.Send = function(self, message, callback)
			local TCP_client = table.tcp
			local id, EXECCOMMAND_package = CreatePackage(message, EXECCOMMAND)
			TCP_client:read_start(function (err, chunk)
				if err then
					-- handle read error
				elseif chunk then
					local String, Type, idServer = ParsingPackage(chunk)
					callback(String, Type, idServer)
				else
					-- handle disconnect
				end
			end)
			TCP_client:write(EXECCOMMAND_package)
		end
	else
		table.Send = function(self, message, callback)
			print("Сообщение не отправлено, к серверу нет подключения")
		end
	end
end

function SourceRcon:Send(message)
	print("Сообщение не отправлено, к серверу нет подключения")
end

function SourceRcon:LoginToServer(password)
	if password then
		ServersPasswd[self] = password
	elseif not ServersPasswd[self] then
		error("Не установлен пароль "..self.ip..":"..self.port)
	end
	local TCP_client = self.tcp
	local ip = self.ip
	local port = self.port
	TCP_client:connect(ip, port, function (err)
		if err then
			TCP_client:shutdown()
			TCP_client:close()
			error("Подключение к серваку не установлено "..ip..":"..port)
		else
			local id, AUTH_package = CreatePackage(password, SERVERDATA_AUTH)
			local num = 0
			TCP_client:read_start(function (err, chunk)
				if err then
					-- handle read error
				elseif chunk then
					local String, Type, idServer = ParsingPackage(chunk)
					if num == 0 and id == idServer and Type == SERVERDATA_RESPONSE_VALUE then
						num = num + 1
					elseif num == 1 and id == idServer and Type == SERVERDATA_AUTH_RESPONSE then
						print("----Мы авторизованы и остановлено чтение TCP "..ip..":"..port)
						ConnectedServer(self, true)
						TCP_client:read_stop()
					else
						print("----Ошибка авторизации "..ip..":"..port)
					end
				else
					-- handle disconnect
				end
			end)
			TCP_client:write(AUTH_package)
		end end)
end

function SourceRcon:initialize(ip_port)
	if type(ip_port) == 'string' then
		local ip, port = string.match(ip_port, "([%w.]+):([%w]+)")
		if ip and port then
			local TCP_client = uv.new_tcp("inet")
			self.port = port
			self.ip = ip
			self.tcp = TCP_client
		else
			error("Input must be a string (ip:port)")
		end
	else
		error("Input must be a string (ip:port)")
	end
end

function SourceRcon.meta:__index(key)
	return SourceRcon[key]
end

function SourceRcon.meta:__newindex(key, value)
	rawset(self, key, value)
end

return sourcercon