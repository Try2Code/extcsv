################################################################################
# Author: Ralf Müller
#
# ==== TODO: Units are automatically selected from the column name. You could add
# units here and they will be used for graphs. I think, this is a premature
# solution, because the file will be edited by nearly every user, so it
# actually is a configutration file. But without units, the graphs loose much
# of their information. There are separate packages for units like
# units.rubyforge.org. But there will allways be the problem, that column names
# cannot be restricted to find a appropriate unit.
################################################################################
module ExtCsvUnits
  Units = 
    {
      :col1             => "kV",
      :col2             => "kV",
      :col3             => "kV",
      :col4             => "kV",
      :col5             => "kV",
      :col6             => "kV",
      :col7             => "kV",
      :col8             => "kV",
      :zeit           => "yyyy-mm-dd hh:mm:ss",
      :time           => "yyyy-mm-dd hh:mm:ss"
    }
end
