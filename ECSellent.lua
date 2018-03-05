-- You think you have a minimalist class implementation? Hold my coffee.
local function class()
	local class = setmetatable({}, {
		__call = function(self, ...)
			return setmetatable({}, self):__init(...)
		end,
	})
	class.__index = class
	return class
end

-- assert() is slow. This is less slow.
local function assertx(val, ...)
    if not val then error(table.concat({...})) end
end

-- Forward declaring classes and arrays
local Component = class()
local components = {}

local System = class()
local systems = {}
local callbacks = {}

local Entity = class()
local entities = {}

--  ____   ___   __  __  ____    ___   _   _  _____  _   _  _____
-- / ___| / _ \ |  \/  ||  _ \  / _ \ | \ | || ____|| \ | ||_   _|
--| |    | | | || |\/| || |_) || | | ||  \| ||  _|  |  \| |  | |
--| |___ | |_| || |  | ||  __/ | |_| || |\  || |___ | |\  |  | |
-- \____| \___/ |_|  |_||_|     \___/ |_| \_||_____||_| \_|  |_|


function Component:__init(name, constructor)
	assertx(not components[name], "Component '", name, "' exists.")

	self.systems = {}
	self.instantiate = constructor

	local system
	for i = 1, #systems do
		system = systems[i]

		for j = 1, #system.required do
			if system.required[j] == name then
				self.systems[#self.systems+1] = system
			end
		end
	end

	components[name] = self
end

--  ____  __   __ ____   _____  _____  __  __
-- / ___| \ \ / // ___| |_   _|| ____||  \/  |
-- \___ \  \ V / \___ \   | |  |  _|  | |\/| |
--  ___) |  | |   ___) |  | |  | |___ | |  | |
-- |____/   |_|  |____/   |_|  |_____||_|  |_|

-- This function is used as a backup for the entityThink and
-- systemThink methods. It is faster than checking for their existance each time
local anonymous = function() end

function System:__init(name, type, required, entityThink, systemThink)
	callbacks[type] = callbacks[type] or {} -- TODO: remove this check
																					-- Hi it's me from the future, what did you mean by this?
	assertx(not callbacks[type][name], "System '", type, ":", name, "' exists.")
	-- Make sure that a callback with this name doesn't exist

	local componentName
	for i = 1, #required do -- For each requirement
		componentName = required[i]
		assertx(components[componentName], "Component '", componentName, "' does not exist.")
		-- Make sure that the required component exists
		local otherComponent = components[componentName]
		if otherComponent then
			otherComponent.systems[#otherComponent.systems+1] = self
		end
	end

	self.required = required
	self.pool = {}
	self.data = {}

	self.entityThink = entityThink or anonymous
	self.systemThink = systemThink or anonymous

	local entity, foundAllComponents
	for i = 1, #entities do -- For each entity
		foundAllComponents = true
		entity = entities[i]
		print("Entity", entity)

		for j = 1, #required do -- Get each required component
			if not entity:get(required[j]) then -- If the component was not found
				foundAllComponents = false break -- Break the loop
			end
		end

		if foundAllComponents then -- If the loop was never broken
			self.pool[#self.pool+1] = entity -- Add the entity to the system's pool
		end
	end

	systems[#systems+1] = self -- Add self to the list of systems
	callbacks[type][name] = self -- Register self in the list of callbacks

	return self
end

function System:doesRequire(component)
	local require
	for i = 1, self.requred do
		if component == self.requred[i] then
			return true
		end
	end
	return false
end

function System:addEntity(entity)
	self.pool[#self.pool+1] = entity
end

function System:removeEntity(entity)
	for key, otherEntity in pairs(self.pool) do
		if otherEntity == entity then
			self.pool[key] = nil
		end
	end
end

--  _____  _   _  _____  ___  _____ __   __
-- | ____|| \ | ||_   _||_ _||_   _|\ \ / /
-- |  _|  |  \| |  | |   | |   | |   \ V /
-- | |___ | |\  |  | |   | |   | |    | |
-- |_____||_| \_|  |_|  |___|  |_|    |_|

function Entity:__init()
	self.components = {}
	self.alive = true

	for i = 1, #entities do
		if not entities[i].alive then
			entities[i] = self
			return self
		end
	end
	entities[#entities+1] =self
	return self
end

function Entity:get(name)
	return self.components[name]
end

function Entity:isInPool(pool)
	for i = 1, #pool do
		if self == pool[i] then
			return true
		end
	end
	return false
end

function Entity:add(name, ...)
	-- Find all systems with component, add entity to system if
	-- entity components and required system components match
	assertx(components[name], "Component '" .. name .. "' does not exist.")
	assertx(not self.components[name], "Entity already has component '" .. name .. "'.")

	local component = components[name]

	self.components[name] = component:instantiate(self, ...)

	local system, foundAllComponents
	for i = 1, #component.systems do
		system = component.systems[i]
		if self:isInPool(system) then break end
		foundAllComponents = true
		for j = 1, #system.required do
			if not self:get(system.required[j]) then
				foundAllComponents = false break
			end
		end

		if foundAllComponents then
			system.pool[#system.pool+1] = self
		end
	end

	return self
end

function Entity:remove(name)
	-- Find all systems with components that math that of
	-- the entity, and remove the entity from the pool
	assertx(components[name], "Component '" .. name .. "' does not exist.")
	assertx(self.components[name], "Entity does not have component '" .. name .. "'.")

	local component = components[name]
	local system
	for i = 1, #component.systems do
		system = component.systems[i]
		system:removeEntity(self)
	end

	self.components[name] = nil
end

--   ___   _____  _   _  _____  ____
--  / _ \ |_   _|| | | || ____||  _ \
-- | | | |  | |  | |_| ||  _|  | |_) |
-- | |_| |  | |  |  _  || |___ |  _ <
--  \___/   |_|  |_| |_||_____||_| \_\

-- You put this in your love.run when inputs happen as follows:

-- if love.event then
-- 	love.event.pump()
-- 	for name, a,b,c,d,e,f in love.event.poll() do
-- 		if name == "quit" then
-- 			if not love.quit or not love.quit() then
-- 				return a or 0
-- 			end
-- 		end
-- 		love.handlers[name](a, b, c, d, e, f)
-- 		event(name, a, b, c, d, e, f)
-- 	end
-- end

-- and

-- event("draw")
-- event("update", dt)

-- At the same time that love.draw and love.update are called

-- Oh and this also means that you can create your own events and call them from anywhere in the code.

local function event(type, ...)
	if not callbacks[type] then return end
	for key, system in pairs(callbacks[type]) do
		system:systemThink(...)

		local entity
		for j = 1, #system.pool do
			entity = system.pool[j]
			if entity.alive then
				system:entityThink(entity, ...)
			end
		end
	end
end

-- Return

return {
	-- Classes
	Component = Component,
	System = System,
	Entity = Entity,
	-- Other
	event = event
}