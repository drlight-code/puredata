--require "strict"
local util = require "util"
local persistence = require "persistence"
local socket = require "socket"
local lfs = require "lfs"

local OscPreset = pd.Class:new():register("osc-preset")

function OscPreset:initialize(name, atoms)
   self.inlets = 2
   self.outlets = 1

   self.presetDir = atoms[1]
   self.preset = nil

   self.cache = {}
   self.blocked = {}
   self.ramping = false

   self.rampStart = {}
   self.rampEnd = {}
   self.rampInterval = 1000
   self.rampTimeStart = nil

   return true
end


function OscPreset:finalize()
end


function OscPreset:in_1(sel, atoms)
   -- pd.post("message not understood: " .. sel)
   -- pd.post(to_string(atoms))
end


function OscPreset:in_1_bang()
   if self.ramping then
      if socket.gettime() > self.rampTimeStart + self.rampInterval then
         self.ramping = false
         self:writeToCache(self.rampEnd)
         self:sendOSC(self.cache)
         return
      end
         
      local fraction = (socket.gettime() - self.rampTimeStart) / self.rampInterval
      self:sendOSC(self:interpolate(fraction))
   end
end


function OscPreset:interpolate(fraction)
   local outMap = {}

--   pd.post(to_string(self.blocked))
   
   for path, atoms_ in pairs(self.rampEnd) do
      local outAtoms = {}

      if self.rampStart[path] ~= nil and self.rampEnd[path] ~= nil and type(self.rampStart[path][3]) == "number" and type(self.rampEnd[path][3]) == "number" then
         for k, v in pairs(atoms_) do
            if k == 1 or k == 2 then
               outAtoms[k] = v
            else
               outAtoms[k] = self.rampStart[path][k] + (self.rampEnd[path][k] - self.rampStart[path][k]) * fraction
            end
         end
         outMap[path] = outAtoms
      end
   end

   return outMap
end


function OscPreset:in_1_save(atoms)
   persistence.store(self.presetDir .. "/" .. atoms[1], self.cache)
end


function OscPreset:in_1_load(atoms)
   -- stop any ramping in progress
   self.ramping = false

   -- load preset into cache and output
   self.preset = atoms[1] or self:randomTarget()
   self:writeToCache(persistence.load(self.presetDir .. "/" .. self.preset))
   self:sendOSC(self.cache)
end


function OscPreset:in_1_ramp(atoms)

   -- if we already ramp to the same target, jump to it immediately
   if self.ramping then
      if self.preset == atoms[1] then
         self:writeToCache(self.rampEnd)
         self:sendOSC(self.cache)
         self.ramping = false
         return
      end
   end

   self.preset = atoms[1] or self:randomTarget()
   self.rampStart = deepcopy(self.cache)
   self.rampEnd = persistence.load(self.presetDir .. "/" .. self.preset)
   self.rampTimeStart = socket.gettime()
   self.ramping = true

   pd.post("ramping to " .. self.preset)
end

function OscPreset:in_1_block(atoms)
   self.blocked[atoms[1]] = 1
   pd.post(to_string(self.blocked))
end

function OscPreset:in_1_unblock(atoms)
   if atoms[1] == nil then
      for k, v in pairs(self.blocked) do
         pd.post(k)
         self:in_1_unblock({k})
      end
   else
      self.rampStart[atoms[1]] = deepcopy(self.cache[atoms[1]])
      self.rampEnd[atoms[1]] = deepcopy(self.cache[atoms[1]])
      self.blocked[atoms[1]] = nil
   end
end

function OscPreset:in_1_sendtyped(atoms)
   self.cache[atoms[1]] = deepcopy(atoms)
   -- table.insert(self.blocked, atoms[1])
   -- self.blocked[atoms[1]] = 1
end


function OscPreset:in_2_float(f)
   self.rampInterval = f / 1000
end


function OscPreset:sendOSC(cache)
   for path, v in pairs(cache) do
      if self.blocked[path] == nil then
         self:outlet(1, "sendtyped", v)
      end
   end
end

function OscPreset:randomTarget()
   local presets = {}
   for file in lfs.dir(self.presetDir) do
      if file ~= "." and file ~= ".." then
         table.insert(presets, file)
      end
   end

   remove(presets, self.preset)
   local index = math.random(#presets)

   return presets[index]
end

function OscPreset:writeToCache(map)
   for path, atoms in pairs(map) do
      self.cache[path] = deepcopy(atoms)
   end
end
