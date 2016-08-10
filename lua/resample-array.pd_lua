local ResampleArray = pd.Class:new():register("resample-array")

function ResampleArray:initialize(name, atoms)
   self.inlets = 2

   self.table1 = atoms[1]
   self.table2 = atoms[2]
   self.scaling = 1
   return true
end

function ResampleArray:finalize()
end

function ResampleArray:in_1_bang()
   self.tSource = pd.Table:new():sync(self.table1)
   self.tTarget = pd.Table:new():sync(self.table2)

   -- for testing
   -- lenSource = self.tSource:length()
   -- for index = 0, self.tSource:length()-1 do
   --    self.tSource:set(index, index / lenSource)
   -- end
   -- self.tSource:redraw()
   
   binSource = 1 / self.tSource:length()
   binTarget = 1 / self.tTarget:length()
   ratio = self.tSource:length() / self.tTarget:length()
   remainder = ratio % 1

   -- zero out target table
   for index = 0, self.tTarget:length() do
      self.tTarget:set(index, 0)
   end

   if self.tSource:length() == self.tTarget:length() then
      for index = 0, self.tSource:length()-1 do
         self.tTarget:set(index, self.tSource:get(index) * self.scaling)
      end
   else
      if ratio > 1 then
         self:downsample()
      elseif ratio < 1 then
         self:upsample()
      end
   end

   self.tTarget:redraw()
end

function ResampleArray:downsample()
   indexTarget = 0
   for indexSource = 0, self.tSource:length()-1 do
      -- pd.post("indexSource: " .. indexSource)
      -- pd.post("indexTarget: " .. indexTarget)

      if (indexSource+1) * binSource < (indexTarget+1) * binTarget then
         -- source bin fully contained in target bin:
         -- just add to target bin, weighted by ratio.

         self.tTarget:set(
            indexTarget,
            self.tTarget:get(indexTarget) +
               self.tSource:get(indexSource) / ratio * self.scaling)
      else
         -- overlapping with bin boundary:
         -- add to first bin weighted by ratio and overlap amount,
         -- increase target bin, add weighted to second.

         fractionLeft =
            ((indexTarget+1) * binTarget - indexSource * binSource) / binSource

         self.tTarget:set(
            indexTarget,
            self.tTarget:get(indexTarget) +
               self.tSource:get(indexSource) * fractionLeft / ratio * self.scaling)
         
         indexTarget = indexTarget + 1
         if indexTarget == self.tTarget:length() then
            break
         end

         self.tTarget:set(
            indexTarget,
            self.tTarget:get(indexTarget) +
               self.tSource:get(indexSource) * (1 - fractionLeft) / ratio * self.scaling)
      end
   end
end

function ResampleArray:upsample()
   indexSource = 0
   for indexTarget = 0, self.tTarget:length()-1 do
      -- pd.post("indexSource: " .. indexSource)
      -- pd.post("indexTarget: " .. indexTarget)

      if (indexTarget+1) * binTarget < (indexSource+1) * binSource then
         -- source bin spans over whole target bin: just add to target bin.

         self.tTarget:set(
            indexTarget,
            self.tTarget:get(indexTarget) +
               self.tSource:get(indexSource) * self.scaling)
      else
         -- two source bins overlap target bin:
         -- add first bin weighted by overlap amount,
         -- increase source bin, add weighted as well.

         fractionLeft =
            ((indexSource+1) * binSource - indexTarget * binTarget) / binTarget

         self.tTarget:set(
            indexTarget,
            self.tTarget:get(indexTarget) +
               self.tSource:get(indexSource) * fractionLeft * self.scaling)

         indexSource = indexSource + 1
         if indexSource == self.tSource:length() then
            break
         end

         self.tTarget:set(
            indexTarget,
            self.tTarget:get(indexTarget) +
               self.tSource:get(indexSource) * (1 - fractionLeft) * self.scaling)
      end
   end
end


function ResampleArray:in_2_float(f)
   self.scaling = f
end
