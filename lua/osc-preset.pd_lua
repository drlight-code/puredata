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
   self.ramping = false

   self.rampStart = {}
   self.rampEnd = {}
   self.rampInterval = 10
   self.rampTimeStart = nil

   return true
end


function OscPreset:finalize()
end


function OscPreset:in_1(sel, atoms)
   pd.post("message not understood: " .. sel)
   pd.post(to_string(atoms))
end


function OscPreset:in_1_bang()
   if self.ramping then
      if socket.gettime() > self.rampTimeStart + self.rampInterval then
         self.ramping = false
         self.cache = self.rampEnd
         self:sendOSC(self.cache)
         return
      end
         
      local fraction = (socket.gettime() - self.rampTimeStart) / self.rampInterval
      self:sendOSC(self:interpolate(fraction))
   end
end


function OscPreset:interpolate(fraction)
   local outMap = {}

   for path, atoms_ in pairs(self.rampEnd) do
      local outAtoms = {}
      if self.rampStart[path] ~= nil and type(self.rampStart[path][3] == "number") and type(self.rampEnd[path][3] == "number") then
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
   self.cache = persistence.load(self.presetDir .. "/" .. self.preset)
   self:sendOSC(self.cache)
end


function OscPreset:in_1_ramp(atoms)

   -- if we already ramp to the same target, jump to it immediately
   if self.ramping then
      if self.preset == atoms[1] then
         self.cache = deepcopy(self.rampEnd)
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
end


function OscPreset:in_1_sendtyped(atoms)
   self.cache[atoms[1]] = deepcopy(atoms)
end


function OscPreset:in_2_float(f)
   self.rampInterval = f
end


function OscPreset:sendOSC(cache)
   for _, v in pairs(cache) do
      self:outlet(1, "sendtyped", v)
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
