local Plotarray = pd.Class:new():register("plotarray")

function Plotarray:initialize(name, atoms)
   self.inlets = 1
   self.table = pd.Table:new():sync(atoms[1])
   return true
end

function Plotarray:finalize()
end

function Plotarray:in_1_float(f)
   for index = 0, self.table:length()-2 do
      self.table:set(index, self.table:get(index + 1))
   end
   self.table:set(self.table:length()-1, f)
   self.table:redraw()
end

-- function Plotarray:in_1_list(l)
--    for k, v in pairs(l) do
--       print(k, v)
--    end
-- end
