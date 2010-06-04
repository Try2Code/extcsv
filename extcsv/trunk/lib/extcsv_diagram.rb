require 'rubygems'
require 'gnuplot'
require 'win32ole' if RUBY_PLATFORM =~ /(win32|cygwin)/i
require 'extcsv_units'

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
                    :time_format    => '"%d.%m\n%H:%M:%S"'
  }
  @@timeColumns = %w[time time_camera zeit]

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
      colunit = Units[col.to_sym].nil? ? col.to_s : "[#{Units[col.to_sym]}]"
      name = [ob.send(col)[0],colunit]
      title += (col.to_sym == :focus) ? name.reverse.join('') : name[0]
      title += " " unless col == group_by.last
    }
    title
  end

  def ExtCsvDiagram.plot(obj,
           group_by, # array[col0, ..., colN]
           x1_col,
           y1_cols,
           x2_col=nil,
           y2_cols=[],
           title='',
           options={})
  
    options = GRAPH_OPTIONS.merge(options)
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

        options[:add_settings].each {|setting|
          md = /^(\w+)/.match(setting)
          plot.set(md[1],md.post_match) unless md.nil?
        }

        # handling of axes
        plot.y2tics 'in'     unless ( y2_cols.nil? or y2_cols.empty? )
        plot.x2tics 'in'     unless ( (x2_col.respond_to?(:empty?) and x2_col.empty?) or x2_col == nil)

        plot.xrange  options[:xrange] unless options[:xrange].nil?
        plot.yrange  options[:yrange] unless options[:yrange].nil?
        plot.x2range options[:x2range] unless options[:x2range].nil?
        plot.y2range options[:y2range] unless options[:y2range].nil?
        plot.xlabel  options[:xlabel]  unless options[:xlabel].nil?
        plot.ylabel  options[:ylabel]  unless options[:ylabel].nil?
        plot.x2label options[:x2label] unless options[:x2label].nil?
        plot.y2label options[:y2label] unless options[:y2label].nil?


        if @@timeColumns.include?(x1_col.to_s)
          plot.xdata 'time'
          plot.timefmt '"%Y-%m-%d %H:%M:%S"'
          plot.format 'x ' + options[:time_format]
        end
        if @@timeColumns.include?(x2_col.to_s)
          plot.x2data 'time'
          plot.timefmt '"%Y-%m-%d %H:%M:%S"'
          plot.format 'x2 ' + options[:time_format]
        end

        # Data for first x-axes
        obj.split(*group_by) {|ob|
          y1_cols.each {|y_col|
            x = ob.send(x1_col)
            y = ob.send(y_col)
            title = enhanceTitleByGroup(group_by,ob)
            plot.data << Gnuplot::DataSet.new([x,y]) {|ds|
              unit = Units[y_col.to_sym].nil? ? '' : "[#{Units[y_col.to_sym]}]"
              ds.using = @@timeColumns.include?(x1_col.to_s) ? '1:3' : '1:2'
              ds.with  = options[:type] + " axes x1y1 lw #{options[:linewidth]}"
              ds.title =  options[:onlyGroupTitle] ? "#{title}" : "#{y_col} #{unit}, #{title}"
            }

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
