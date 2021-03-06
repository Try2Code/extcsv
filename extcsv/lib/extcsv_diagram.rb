require 'rubygems'
require 'gnuplot'
require 'win32ole' if RUBY_PLATFORM =~ /(win32|cygwin)/i
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
      :col1  => "kV",
      :col2  => "kV",
      :col3  => "kV",
      :col4  => "kV",
      :col5  => "kV",
      :col6  => "kV",
      :col7  => "kV",
      :col8  => "kV",
      :zeit  => "yyyy-mm-dd hh:mm:ss",
      :time  => "yyyy-mm-dd hh:mm:ss",
      :depth => "m",
      :Temp  => "degC"
    }
end
################################################################################
# This module provides separate plotting methods 
module ExtCsvDiagram
  include ExtCsvUnits
  GRAPH_OPTIONS = {
                    :type           => "linespoints",
                    :linewidth      => "1",
                    :terminal       => 'x11',
                    :size           => nil,
                    :filename       => nil,
                    :title          => nil,
                    :addSettings    => [],
                    :label_position => "left",
                    :label?         => true,
                    :grid           => true,
                    :xrange         => nil,
                    :yrange         => nil,
                    :x2range        => nil,
                    :y2range        => nil,
                    :y1limit        => nil,
                    :y2limit        => nil,
                    :using          => nil,
                    :datasets       => {:using => []},
                    :logscale       => nil,
                    :add_settings   => [], 
                    :point_label?   => false,
                    :output_time_format => '"%Y-%m-%d\n%H:%M:%S"',
                    :input_time_format  => '"%Y-%m-%d\n%H:%M:%S"'
  }
  @@timeColumns = %w[time time_camera zeit date datetime timestamp]

  @@ColorLow = 0x0000ad
  @@ColorUp  = 0xffffff

  def ExtCsvDiagram.set_pointlabel(obj, plot, x_col, x, y, label_col=nil, size='10')
    timemode = (%w[zeit zeitstempel time timestamp].include?(x_col.to_s))
    x.each_index {|i|
      point  = (timemode) ? "\"#{x[i].to_s}\"" : x[i].to_s
      point += ",#{y[i].to_s}"
      unless label_col.nil?
        label = obj.send(label_col)[i]
      else
        label = point
      end
      plot.label  "'#{label}' at #{point} font 'Times,#{size}' offset 1,1"
    }
  end

  def ExtCsvDiagram.set_limit(plot,x,xIsTime,axes,limit,limitname,options)
    if xIsTime
      xmin, xmax = [x.min,x.max]
      using = '1:3'
    else
      xtof = x.collect {|v| v.to_f}
      xmin, xmax = [xtof.min,xtof.max]
      using = '1:2'
    end
    plot.data << Gnuplot::DataSet.new([
                                      [xmin,xmax],
                                      [limit,limit]
    ]) {|ds| 
      ds.with = "lines axes #{axes} lw #{options[:linewidth]}"
      ds.title = limitname.nil? ? '' : limitname
      ds.using = using

    }
  end
  
  def ExtCsvDiagram.enhanceTitleByGroup(group_by,ob)
    title = ''
    group_by.each {|col|
      unit    = Units[col.to_sym]
      colunit = unit.nil? ? col.to_s : unit
      name    = [ob.send(col)[0],colunit]
      title  += (col.to_sym != :focus) ? name.join('') : name[0]
      title  += " " unless col == group_by.last
    }
    title
  end

  def ExtCsvDiagram.checkColumns(obj,*cols)
    cols.each {|col|
      next if col.kind_of?(Hash)
      unless obj.datacolumns.include?(col.to_s)
        print "[plot] Input data does NOT contain column '#{col.to_s}'\n"
        raise ArgumentError
      end
    }
  end

  def ExtCsvDiagram.setRangeAndLabel(plot,options)
    plot.xrange  options[:xrange]  unless options[:xrange].nil?
    plot.yrange  options[:yrange]  unless options[:yrange].nil?
    plot.xlabel  options[:xlabel]  unless options[:xlabel].nil?
    plot.ylabel  options[:ylabel]  unless options[:ylabel].nil?
    plot.x2range options[:x2range] unless options[:x2range].nil?
    plot.y2range options[:y2range] unless options[:y2range].nil?
    plot.x2label options[:x2label] unless options[:x2label].nil?
    plot.y2label options[:y2label] unless options[:y2label].nil?
  end
  def ExtCsvDiagram.setXTimeAxis(plot,input_time_format,output_time_format,*xColumns)
    xColumns.each_with_index {|xcol,i|
      next if xcol.nil? or xcol.kind_of?(Hash)
      if @@timeColumns.include?(xcol.to_s)
        plot.timefmt input_time_format
        if 0 == i
          plot.xdata 'time'
          plot.format 'x ' + output_time_format
        else
          plot.x2data 'time'
          plot.format 'x2 ' + output_time_format
        end
      end
    }
  end

  def ExtCsvDiagram.addSettings(plot,settings)
    settings.each {|setting|
      md = /^(\w+)/.match(setting)
      plot.set(md[1],md.post_match) unless md.nil?
    }
  end

  def ExtCsvDiagram.setKeys(plot,options)
    plot.key options[:label_position]
    plot.key 'off' unless options[:label?]
  end

  def ExtCsvDiagram.setOutput(plot,options)
    size = (options[:size].nil?) ? '' : " size #{options[:size]}"
    plot.terminal options[:terminal] + size
    plot.output options[:filename] + "." + options[:terminal].split(" ")[0]
  end

  def ExtCsvDiagram.colors(nColors)
    colors = []
    step = (@@ColorUp - @@ColorLow)/(nColors-1)
    nColors.times {|i| colors << "#"+(@@ColorLow + i*step).to_s(16)}
    colors
  end

  def ExtCsvDiagram.addDataToPlot(plot,obj,xColumn,yColumn,groupBy,options)
    x = obj.send(xColumn)
    y = obj.send(yColumn)
    title = enhanceTitleByGroup(groupBy,obj)
    plot.data << Gnuplot::DataSet.new([x,y]) {|ds|
      unit = Units[yColumn.to_sym].nil? ? '' : "[#{Units[yColumn.to_sym]}]"
      ds.using = @@timeColumns.include?(xColumn.to_s) ? '1:3' : '1:2'
      ds.with  = options[:type]
      ds.title =  options[:onlyGroupTitle] ? "#{title}" : "#{yColumn} #{unit}, #{title}"
    }
    return [x,y]
  end
  def ExtCsvDiagram.plot_xy(obj,xColumn,yColumn,title,options={})
    checkColumns(obj,xColumn,yColumn) unless options[:skipColumnCheck]
    options        = GRAPH_OPTIONS.merge(options)
    #outputfilename = (options[:filename].nil?) ? obj.filename : options[:filename]
    groupBy        = (options[:groupBy]).nil? ? [] : options[:groupBy]
    Gnuplot.open {|gp|
      Gnuplot::Plot.new(gp) {|plot|
        plot.title "'" + title + "'"
        setKeys(plot,options)

        setOutput(plot,options) unless 'x11' == options[:terminal]

        plot.grid if options[:grid]

        addSettings(plot,options[:addSettings]) unless options[:addSettings].empty?

        setRangeAndLabel(plot,options)

        setXTimeAxis(plot,options[:input_time_format],options[:output_time_format],xColumn)

        # Data for first x-axes
        obj.split(*groupBy) {|obj|
          x,y = ExtCsvDiagram.addDataToPlot(plot,obj,xColumn,yColumn,groupBy,options)

          # set labels if requested
          set_pointlabel(ob,plot, xColumn, x,y, options[:label_column],options[:label_fsize]) if options[:point_label?]
        }
      }
    }
  end
  def ExtCsvDiagram.plot(obj,
           group_by, # array[col0, ..., colN]
           x1_col,
           y1_cols,
           x2_col=nil,
           y2_cols=[],
           title='',
           options={})

    ExtCsvDiagram.checkColumns(obj,*([group_by,x1_col,y1_cols,x2_col,y2_cols].flatten.uniq.compact))

    options        = GRAPH_OPTIONS.merge(options)
    outputfilename = (options[:filename].nil?) ? obj.filename : options[:filename]

    Gnuplot.open {|gp|
      Gnuplot::Plot.new(gp) {|plot|
        plot.title "'" + title + "'"
        plot.key options[:label_position]
        plot.key 'off' unless options[:label?]
        if options[:terminal] != 'x11'
          size = (options[:size].nil?) ? '' : " size #{options[:size]}"
          plot.terminal options[:terminal] + size
          plot.output outputfilename + "." + options[:terminal].split(" ")[0]
        end

        plot.grid if options[:grid]

        addSettings(plot,options[:addSettings]) unless options[:addSettings].empty?

        # handling of axes
        plot.y2tics 'in' unless ( y2_cols.nil? or y2_cols.empty? )
        plot.x2tics 'in' unless ( x2_col.nil? or x2_col.kind_of?(Hash) )

        setRangeAndLabel(plot,options)

        setXTimeAxis(plot,options[:input_time_format],options[:output_time_format],x1_col,x2_col)

        # Data for first x-axes
        obj.split(*group_by) {|ob|
          y1_cols.each {|y_col|
            x,y = ExtCsvDiagram.addDataToPlot(plot,ob,x1_col,y_col,group_by,options)

            # set labels if requested
            set_pointlabel(ob,plot, x1_col, x,y, options[:label_column],options[:label_fsize]) if options[:point_label?]
          }
          y2_cols.each {|y_col|
            x = ob.send(x1_col)
            axes = "x1y2"
            unless ( (x2_col.respond_to?(:empty?) and x2_col.empty?) or x2_col == nil)
              x = ob.send(x2_col)
              axes = "x2y2"
            end
            title = enhanceTitleByGroup(group_by,ob)
            y = ob.send(y_col)
            plot.data << Gnuplot::DataSet.new([x,y]) {|ds|
              unit  = Units[y_col.to_sym].nil? ? '' : "[#{Units[y_col.to_sym]}]"
              ds.using = ( (/x2/.match(axes) and @@timeColumns.include?(x2_col.to_s)) or (/x1/.match(axes) and @@timeColumns.include?(x1_col.to_s)) ) ? '1:3' : '1:2'
              ds.with  = options[:type] + " axes #{axes} lw #{options[:linewidth]}"
              ds.title = "#{y_col} #{unit}, #{title}"
            }
            # set labels if requested
            set_pointlabel(ob,plot, (axes == "x2y2") ? x2_col : x1_col, x,y, options[:label_column],options[:label_fsize]) if options[:point_label?]
          }
        }
        # show limits for each y-axes
        unless y1_cols.empty?
          if options[:y1limits].kind_of?(Array)
            x = obj.send(x1_col)
            options[:y1limits].each {|limit| set_limit(plot,
                                                       x,
                                                       @@timeColumns.include?(x1_col.to_s),
                                                       "x1y1",
                                                       limit,
                                                       options[:y1limitname],
                                                       options)}
          end
        end
        unless y2_cols.empty?
          if options[:y2limits].kind_of?(Array)
            xcol, axes = x2_col.to_s.empty? ? [x1_col,"x1y2"] : [x2_col,"x2y2"]
            x = obj.send(xcol)
            options[:y2limits].each {|limit| set_limit(plot,
                                                       x,
                                                       @@timeColumns.include?(xcol.to_s),
                                                       axes,
                                                       limit,
                                                       options[:y2limitname],
                                                       options)}
          end
        end
      }
    }
  end
  
  def ExtCsvDiagram.multiplot()
  end
end
