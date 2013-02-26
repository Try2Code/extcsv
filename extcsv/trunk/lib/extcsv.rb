require 'csv'
require 'ostruct'
require 'extcsv_diagram'

class Nil
  def to_s; ''; end
  def to_a; []; end
  def empty?; true; end
end

class Array
  def complement(other)
    (self - other) + (other - self)
  end
end

# = CSV-like Data processing made easy
# (see project page: http://rubyforge.org/projects/extcsv)
#
# The extcsv package should enable you to navigate and operate on csv-like data
# as easy and comfortable as possible. The main restriction is, that the
# columns are named, i.e. the first line of a data file has to contain a header with string-like entries.
#
# Data can be read from files, strings, hashes or arrays.
#
# Have a look at my other projects for
# correlation[http://extcsv.rubyforge.org/correlation] and {spectral filtering}[http://extcsv.rubyforge.org/spectralfilter].
#
# ==== Author: Ralf Mueller
# ==== License: BSD - see {license file}[http:/extcsv.rubyforge.org/svn/extcsv/trunk/LICENSE]
################################################################################
class ExtCsv < OpenStruct
  VERSION = '0.12.2'

  include Comparable
  include Enumerable

  # Allowed data types
  TYPES = %w{csv ssv tsv psv txt plain}

  # Allowed input modes, db and url are not supported, yet
  MODES = %w{file hash array string}

  # column names from different file type, which that have the same
  # meaning
  DOUBLE_COLUMNS = {}

  # Non-Data fields
  METADATA = %w{mode datatype datacolumns cellsep rowsep filename filemtime}

  # ShunkSize for handling large objects with MRI
  ShunkSize = 65536

  # mode can be one of the allowed MODES
  # datatype can be one of the TYPES
  #
  # === Example
  #       ExtCsv.new("file","txt","Data.txt")
  #       ExtCsv.new("file","csv","Ergebniss.csv")
  #
  #
  def initialize(mode, datatype, params)
    obj_hash               = {}
    obj_hash[:mode]        = mode
    obj_hash[:datatype]    = datatype
    obj_hash[:datacolumns] = []

    if not MODES.include?(mode) or not TYPES.include?(datatype)
      puts "use '#{MODES.join("','")}' for first " +
           "and '#{TYPES.join(",")}' for second parameter " +
           "datatype was '#{datatype}', mode was '#{mode}'"
      raise 
    end

    # Grep data from the given source, e.g. database or file
    case obj_hash[:mode]
    when "string"
      set_separators(obj_hash)
      parse_content(params,obj_hash)
    when "file"
      if File.exist?(params)
        obj_hash[:filename] = params
      else
        $stdout << "The input file '#{params}' cannot be found!\n"
        $stdout << "Please check path and filename." << "\n"
        return
      end
      obj_hash[:filemtime] = File.mtime(obj_hash[:filename]).strftime("%Y-%m-%d %H:%M:%S")
      set_separators(obj_hash)
      parse_content(IO.read(obj_hash[:filename]),obj_hash)
    when "hash"
      obj_hash = params
      # update the metacolumns
      #test $stdout << obj_hash.keys.join("\t")
      obj_hash[:datacolumns] = (obj_hash.keys.collect {|dc| dc.to_s} - METADATA)
    when "array"
      params.each {|v|
        key = v[0]
        obj_hash[:datacolumns] << key
        obj_hash[key] = v[1..-1]
      }
    end
    super(obj_hash)
  end
  
  def set_separators(obj_hash)
    obj_hash[:cellsep]  = case obj_hash[:datatype]
                          when "txt","tsv" then "\t"
                          when "ssv"       then ';'
                          when "csv"       then ','
                          when "psv"       then "|"
                          end
    obj_hash[:rowsep]   = "\r\n"
  end

  # Main method for parsing input strings. Comments and other special
  # signs are treated as follows
  # * first line is taken to be the header with columns names. If that
  #   line starts with a comment sign (#), this sign is removed.
  # * any other line which starts with '#' is ignored
  # * german umlaute are translated into asci-conform versions for
  #   columns names 
  #   TODO: This is some kind of arbitrary, there should be a more general
  #   solution
  # * spaces are removed from columns names
  # * brackets are translated into underscores
  # * '+' and '-' are changed into the correspondig words
  # * empty lines are removed
  # * dots are changed into underscores for columns names
  # * commas are converteed into dots (german number notation) unless the commy is the cell separator
  # * the greek sign for mu is changes into mu
  def parse_content(filecontent,obj_hash)
    content     = []
    # convert numbers into us. notation if this doesn't crashes with the columns separator
    filecontent = filecontent.gsub(',','.') unless obj_hash[:datatype] == "csv"
    # remove blank lines
    filecontent = filecontent.gsub(/\r\r/,"\r").gsub(/(\r\n){2,}/,"\r\n").gsub(/\n{2,}/,"\n")
    csv         = CSV.parse(filecontent, :col_sep => obj_hash[:cellsep])#, obj_hash[:rowsep])

    # read @datatype specific header
    header = csv.shift
    # remove comments sign from the header
    header[0].gsub!(/^#+/,'') if /^#/.match(header[0])

    header.each_with_index {|key,i|
      key = "test" if key.nil?
      header[i] = key.downcase.tr(' ','').tr('"','')\
        .gsub(/\[\w*\]/,"")\
        .gsub(/^\+/,"plus_").gsub(/^-/,"minus_")\
        .tr('-','_').tr('+','_')\
        .gsub(/(\(|\))/,'_').tr('.','_').chomp
    }
    content << header
    # read the data itself
    csv.each {|row| content << row if row.to_a.delete_if(&:nil?).size != 0 }

    # further processing according to the input type
    case obj_hash[:datatype]
    when "csv","ssv","psv","txt","tsv"
      # check if rows have the same lenght
      contents_size = content.collect {|row| row.size}
      content.each_with_index {|row,i|
        content[i] = row[0...contents_size.min]
      } unless contents_size.min == contents_size.max
    end
    content = content.transpose

    # file specific changement of the column names: for each physical meaning
    # their should be only one column
    content.each {|item|
      key = nil
      DOUBLE_COLUMNS.keys.each {|k|
        md = /#{k}/.match(item[0])
        unless md.nil?
          key = DOUBLE_COLUMNS[k]
          break
        end
      }
      key   = item[0] if key.nil?
      value = item[1..-1]
      value.each_index {|i| value[i] = (value[i].nil?) ? '' : value[i].to_s}
      obj_hash[key.to_sym] = value
      obj_hash[:datacolumns] << key
      # TODO: the following is some kind of german specific DateTime
      # conversion, see change_time_format definition for more info.
      # Maybe there is a more general version using the Time.parse method
      change_time_format(value) if key == "zeit"
    }
  end

  # Create an auto index
  def index
    (0...rsize).to_a
  end

  # Do a selection by the index of the dataset inside the receiver. This does
  # not change the receiver.
  def selectBy_index(indexes)
    new_table = {}
    @table.each {|key, value|
      if METADATA.include?(key.to_s) or not value.kind_of?(Array)
        new_table[key] = value
      else
        new_table[key] = value.values_at(*indexes) 
      end
    }
    self.class.new("hash","plain",new_table)
  end
  
  # Selection can be made by regular expressions. This method decides,
  # with method is used.
  def is_regexp?(pattern, key)
    return false unless /(<|<=|>=|>)\s*/.match(pattern).nil?
    case key 
    when "zeit"
      pattern = pattern.gsub(/(-|\.\d)/,'')
    else
      pattern = pattern.gsub(/\.\d/,'')
    end
    pattern != Regexp.escape(pattern)
  end

  # This Function uses a hash parameter, where the key must be the name of an
  # instance variable, i.g. params = 
  # * {:col1 => "4", :col2 => "100", :col3> "80"}
  # * {:col1 => /(4|5)/, :col2 => "<500", :col3> ">=80"}
  # Searching can be done directly, which uses '==' to match, via regular
  # expressions of by simple mathematical operarions:
  # * <
  # * <=
  # * >
  # * >=
  def selectBy(selection)
    operations = %w{<= >= == < > !=}
    type = nil

    # transform selection keys into symbols. This make the further usage
    # a lot easyer and allows to take strings or symbols for columns
    # names
    # ATTENTION: DO NOT MIX THE USAGE OF STRING AND SYMBOLS!
    #   This can lead to a data loss, because e.g. {:k => 4, "k" => 3} will be
    #   transformed into {:k=>3}
    selection.keys {|k| 
      if k.kind_of?(String)
        v                   = selection.delete(k)
        selection[k.to_sym] = v
      end
    }
    vars = selection.keys
    # test for unknown selection variables
    vars.each {|attribute|
      unless @table.has_key?(attribute)
        $stdout << "Object does NOT hav the attribute '#{attribute}'!"
        raise 
      end
    }
    # default is the lookup in the whole array of values for each var
    lookup = (0...@table[vars[0]].size).to_a

    vars.each { |var|
      operation = nil
      value     = nil
      # needle can be a real value, a math. comparision or a regular expression
      needle = selection[var]

      if needle.kind_of?(Numeric)
        operation = "=="
        value     = needle
        type      = :numeric
          #test stdout << needle << " #### #{needle.class} ####\n"
          #test stdout << type.to_s << "\n"
      elsif needle.kind_of?(Regexp)
        operation = Regexp.new(needle)
        type      = :regexp
          #test stdout << needle << " #### #{needle.class} ####\n"
          #test stdout << type.to_s << "\n"
      elsif needle.kind_of?(String)
        if (md = /(#{operations.join("|")})([^=].*)/.match(needle); not md.nil?)
          # separate the operation
          operation = md[1]
          value     = md[2].strip
        else
          operation = '=='
          value     = needle
        end
        if (value == "")
          # value is missing
          $stdout << "value for variable '#{var}' is missing\n"
          raise
        elsif ( (value != "0" and (value.to_f.to_s == value or value.to_i.to_s == value)) or (value == "0") )
          # A: numerical compare
          value = value.to_f
          type      = :numeric
          #test stdout << value << " #### #{value.class} ####\n"
          #test stdout << type.to_s << "\n"
        else
          # B: String-like compare
          # quoted if not allready quoted
          value = "'" + value + "'" unless ( /'(.*[^']?.*)'/.match(value) or /"(.*[^"]?.*)"/.match(value) )
          type      = :string
          #test $stdout << value << " #### #{value.class} ####\n"
          #test $stdout << type.to_s << "\n"
        end
      else
        $stdout << "The Parameter '#{needle}' has the wrong Type. " + 
                   "Please use numeric values, stings or regular expressions (e.g. /(^50$|200)/)\n"
        raise
      end
      #test stdout << "\n NEW VALUE :::::::::::::::\n"
      obj_values  = @table[var]
      size        = @table[var].size
      checkValues = [(0...size).to_a, obj_values].transpose
      if ShunkSize < size
        container = []
        (0..size/ShunkSize).collect {|i|
          checkValues.values_at(*(lookup[i*ShunkSize,ShunkSize]))
        }.each {|v| v.each {|vv| container << vv} }
        checkValues = container
      else
        checkValues = checkValues.values_at(*lookup)
      end

      if operation.kind_of?(Regexp)
        lookup = lookup & checkValues.find_all {|i,v| operation.match(v.to_s)}.transpose[0].to_a
      else
        lookup = lookup & checkValues.find_all {|i,v|
          next if v.nil?
          next if v.empty? if v.respond_to?(:empty?)
          v = "'" + v + "'" if type == :string
          #test $stdout <<[v,operation,value].join(" ") << "\n"
          eval([v,operation,value].join(" "))
        }.transpose[0].to_a
      end
    }
    selectBy_index(lookup) 
  end

  # Find the dataset, with the values of key closest to he value-parameter
  def closest_to(key, value)
    # try to select directly
    _ret = selectBy(key => value)
    return _ret unless _ret.empty?

    # grabbing for numerics
    # the operation '<=' and '>=' can be left out, because, they would have
    # been matcher before
    _smaller = selectBy(key => " < #{value}")[-1]
    _greater = selectBy(key => " > #{value}")[0]

    _smaller_diff = (_smaller.send(key)[0].to_f - value).abs
    _greater_diff = (_greater.send(key)[0].to_f - value).abs
    return (_smaller_diff < _greater_diff) ? _smaller : _greater
  end
  
  # Transform the time from "dd.mm.yyyy hh:mm:ss" to "yyyy-mm-dd hh:mm:ss"
  # For the comparison the timestamps this format is usefull, because the '<=>'
  # comparison of the strings coincides with the temporal order
  def change_time_format(times)
    times.each_with_index {|time,i|
      # if there is no space in time, it is considered a time in
      # format hh:mm
      if time.count(" ") == 0
        time = Time.new.strftime("%d.%m.%Y ") + time
      end
      dATE, tIME = time.split(" ")
      day, month, year = dATE.split(".")
      if tIME.nil?
        times[i] = [year,month,day].join('-')
      else
        hour, minute, second = tIME.split(":")
        if second.nil?
          times[i] = [year,month,day].join('-') + " " + [hour,minute].join(':')
        else
          times[i] = [year,month,day].join('-') + " " + [hour,minute,second].join(':')
        end
      end
    }
  end

  # Return an array of datasets, which contain of the values of the gives
  # columns in order of these columns, e.g.
  # [[col0_val0,col1_val0,...],...,[col0_valN, col1_valN,...]]
  def datasets(*columns)
    retval = [] 

    # preset the selected columns to select
    columns = datacolumns if columns.empty?

    columns.each {|col| retval << @table[col.to_sym]}
    retval.transpose
  end
  def columns(*columns)
    h = {}
    columns.each{|col| h[col] = self.send(col)}
    return self.class.new("hash","plain",h)
  end
  def clear
    @table.each {|k,v| @table[k] = [] if v.kind_of?(Array)}
  end
  def empty?
    return true if @table.empty?
    @table.each {|k,v| 
      if ( v.kind_of?(Array) and v == [])
        return true
      end
    }
    false
  end

  # 
  # Different size definitions
  def size
    @table[datacolumns[0].to_sym].size
  end

  def numberOfRows
    @table[datacolumns[-1].to_sym].size
  end
  alias :rsize :numberOfRows

  def numberOfColumns
    datacolumns.size
  end
  alias :csize :numberOfColumns

  def globalsize
    numberOfRows*numberOfColumns
  end

  def deep_copy
    copy = {}
    @table.each {|k,v| copy[k] = v.clone}
    copy
  end

  #
  # Perform a persistent change on the receiver. Usage like change.
  def operate_on!(column, operation)
    values = send(column)
    send(column).each_index {|i|
      newval          = eval("#{values[i]} #{operation}")
      send(column)[i] = newval.to_s unless newval.nil?
    }
    self
  end

  #
  # Perform a change on a object copy. column can be any attribute of the
  # object and the operation has to be a string, which can be evaluated by the
  # interpreter, e.g. "+ 0.883" or "*Math.sin(#{myvar})"
  def operate_on(column, operation)
    self.class.new("hash","plain",deep_copy).operate_on!(column,operation)
  end

  def set_column!(column, expression)
    values = send(column)
    send(column).each_index {|i|
      send(column)[i] = eval(expression).to_s
    }
    self
  end
  def set_column(column, expression)
    self.class.new("hash","plain",deep_copy).set_column!(column,expression)
  end

  #
  # Iteration over datasets containing values of all columns
  def each(&block)
    objects = []
    (0...size).each {|i| objects << selectBy_index([i])}
    objects.each(&block)
  end

  #
  # iterator over different values of key
  def each_by(key,sort_uniq=true, &block)
    if sort_uniq
      send(key).uniq.sort.each(&block)
    else
      send(key).each(&block)
    end
  end
  
  #
  # each_obj iterates over the subobject of the receiver, which belong to the
  # certain value of key
  def each_obj(key, &block)
    key = key.to_sym
    retval = []
    send(key).sort.uniq.each {|value|
      retval << selectBy(key => value)
    }
    if block_given?
      retval.each(&block)
    else
      retval
    end
  end

  # :call-seq:
  # split.(:col0,...,:colN) {|obj| ...}
  # split.(:col0,...,:coln) -> [obj0,...,objM]
  # 
  # split is a multi-key-version of each_obj. the receiver is splitted into
  # subobject, which have constant values in all given columns
  #
  # eg.
  # <tt>obj.split(:kv, :focus) {|little_obj| little_obj.kv == little_kv.uniq}</tt>
  #
  # or
  #
  # <tt>obj.split(:kv, :focus) = [obj_0,...,obj_N]</tt>
  def split(*columns, &block)
    retval = []
    deep_split(columns, retval)
    if block_given?
      retval.each(&block)
    else
      retval
    end
  end

  # really perform the splitting necessary for split
  def deep_split(columns, retval)
    case
    when (columns.nil? or columns.empty? or size == 1)
      retval << self
    when (columns.size == 1 and send(columns[0]).uniq.size == 1)
      retval << self
    else
      each_obj(columns[0]) {|obj| obj.deep_split(columns[1..-1], retval)}
    end
  end

  # hash representation of the data
  def to_hash
    @table
  end

  def add(name, value)
    new_ostruct_member(name)
    self.send(name.to_s+"=", value)
    self.datacolumns << name.to_s unless self.datacolumns.include?(name.to_s)
   return
  end

  # array representatio nof the data
  def to_ary
    @table.to_a
  end

  # Texcode for the table with vertical and horzontal lines, which contains
  # values of the given columns
  def to_texTable(cols,col_align="c",math=false)
    hline = '\\hline'
#      tex << '$' + cols.each {|col| col.sub(/(.+)_(.+)/,"\\1_\{\\2\}")}.join("$&$") + '$' + "\\\\\n"
    tex = ''
    tab_align = ''
    cols.size.times { tab_align << '|' + col_align }
    tab_align << '|'
    tex << '\begin{tabular}{' + tab_align + '}' + hline + "\n"
    if math
      tex << '$' + cols.join("$&$").gsub(/(\w+)_(\w+)/,"\\1_\{\\2\}") + '$' + '\\\\' + hline + "\n"
    else 
      tex << cols.join(" & ") + '\\\\' + hline +"\n"
    end
    datasets(cols).each {|dataset|
      tex << dataset.join(" & ") + '\\\\' + hline + "\n"
    }
    tex << '\end{tabular}' + "\n"
    tex
  end
  
  # String output. See ExtCsvExporter.to_string
  def to_string(stype,sort=true)
    header = sort ? datacolumns.sort : datacolumns
      ExtCsvExporter.new("extcsv",
                            ([header] + 
                               datasets(*header)).transpose
                           ).to_string(stype)
  end
  def to_file(filename, filetype="txt")
    File.open(filename,"w") do |f|
      f << to_string(filetype)
    end
  end
  
  # Equality if the datacolumns have the save values, i.e. as float for numeric
  # data and as strings otherwise
  def eql?(other)
    return false unless ( self.datatype == other.datatype or self.datatype  == other.datatype)

    return false unless self.datacolumns.sort == other.datacolumns.sort

    datacolumns.each {|c| return false unless send(c) == other.send(c) }
    
    return true
  end

  def diff(other)
    diffdatatype = [self.datatype, other.datatype]
    return diffdatatype unless diffdatatype.uniq.size == 1

    diffdatacolums = self.datacolumns.complement(other.datacolumns)
    return [self.diffdatacolums,other.datacolumns] unless diffdatacolums.empty?
    
    datacolumns.each {|c| 
      diffcolumn = send(c).complement(other.send(c))
      return diffcolumn unless diffcolumn.empty?
    }
  end

  def <=>(other)
    compare = (self.size <=> other.size)
    #$stdout << compare.to_s << "\n"
    compare = (datacolumns.size <=> other.datacolumns.size) if compare.zero?
    #$stdout << compare.to_s << "\n"# if compare.zero?
    #compare = (self.datasets(* self.datacolumns.sort) <=> other.datasets(* other.dataacolumns.sort)) if compare.zero?
    #$stdout << compare.to_s << "\n"# if compare.zero?
    compare = (to_s.size <=> other.to_s.size) if compare.zero?
    #
    #$stdout << compare.to_s << "\n" if compare.zero?
    compare = (to_s <=> other.to_s) if compare.zero?
    #$stdout << compare.to_s << "\n" if compare.zero?
    #$stdout << "##################################\n"
    compare
  end
  
  # has to be defined for using eql? in uniq
  def hash;0;end

  def [](*argv)
    copy = @table.dup
    copy.each {|k,v| copy[k] = (argv.size == 1 and argv[0].kind_of?(Fixnum)) ? [v[*argv]] : v[*argv] if v.kind_of?(Array) }
    ExtCsv.new("hash","plain",copy)
  end
  alias :slice :[]

  def concat(other)
    ExtCsv.concat(self,other)
  end
  alias :+ :concat
  alias :<< :concat

  def combine(other)
    return self unless other.kind_of?(self.class)
    1.times do 
      warn "Both object should have the same number of datasets to be combined"
      warn "Size of first Object (#{filename}): #{rsize}"
      warn "Size of second Object (#{other.filename}): #{other.rsize}"
      return nil
    end unless rsize == other.rsize
    objects, datatypes =  [self, other],[datatype,other.datatype]
    udatatypes = datatypes.uniq
    # 
    case udatatypes.size
    when 1
      hash = marshal_dump.merge(other.marshal_dump)
    else
      if datatypes.include?("ssv") or datatypes.include?("csv")
        csv_index  = datatypes.index("ssv") || datatypes.index("csv")
        qpol_index = csv_index - 1
        objects[csv_index].modyfy_time_column
        hash = objects[csv_index].marshal_dump.merge(objects[qpol_index].marshal_dump)
        hash[:filename] = []
        hash[:filename] << objects[csv_index].filename << objects[qpol_index].filename
      else
        hash = marshal_dump.merge(other.marshal_dump)
        hash[:filename] = []
        hash[:filename] << other.filename << filename
      end
    end
    # preserving the filenames 
    hash[:filemtime] = [self.filemtime.to_s, other.filemtime.to_s].min
    ExtCsv.new("hash","plain",hash)
  end
  alias :& :combine

  # Objects in ary_of_objs are glues in a new ExtCsv object. They should have
  # the same datatype
  # TODO: if at least two objects have different columns, the composite objetc
  # should have empty values at the corresponding dataset. So be carefull with
  # this version of concat!
  def ExtCsv.concat(*ary_of_objs)
    return unless ary_of_objs.collect{|obj| obj.datatype}.uniq.size == 1
    ary_of_objs.flatten! if ary_of_objs[0].kind_of?(Array)
    new_obj_hash = {}
    ary_of_objs.each {|obj|
      obj.to_hash.each {|k,v|
        new_obj_hash[k] = v.class.new unless new_obj_hash[k].kind_of?(v.class)
        new_obj_hash[k] += v 
      }
    }
    new_obj_hash[:filename] = ary_of_objs.collect{|td| td.filename}
    new_obj_hash[:filemtime] = ary_of_objs.collect{|td| td.filemtime}
    ExtCsv.new("hash","plain",new_obj_hash)
  end

  def ExtCsv.combine(obj, obj_=nil)
    obj.combine(obj_)
  end

  def plot(*args)
    ExtCsvDiagram.plot(self,*args)
  end
  private :deep_copy, :set_separators, :parse_content, :change_time_format
end

class ExtCsvExporter
  DEFAULT_FILENAME = "measurement.txt"

  # See to_string for allowed data types. <em>data_content</em> accepts the
  # output from ExtCsv.to_ary.
  def initialize(data_type, data_content)
    @line_sep  = "\n"
    @data_type = data_type
    @content   = data_content
  end

  # Optional string types are:
  # * csv , separation by ','
  # * ssv, separation by ';'
  # * tsv, separation by '\t'
  # * psv, separation by '|'
  # * xml, see to_xml
  def to_string(string_type,enc="en")
    string_type = "xml" if string_type.nil? or string_type.empty?
    out = ''
    case string_type
    when "csv"
      sep = ","
    when "ssv"
      sep = ";"
    when "tsv" , "txt"
      sep = "\t"
    when "psv"
      sep = "|"
    when "xml" 
      out = to_xml
    when "tex"
    else
      puts "Wrong type! Use xml, tex, csv, ssv, psv, txt or tsv instead."
      raise
    end
    @content.transpose.each {|data_set|
      out << data_set.join(sep) + @line_sep
    } unless string_type == "xml"
    #out.gsub(/\./,",") if enc == "de"
    out
  end

  # XML-Documents must be treated separately: tags are named like the attributes.
  def to_xml
    xml = "<?xml version='1.0' encoding='ISO-8859-1'?>\n"
    xml << "<" + @data_type + ">\n"
    output_array = @content.transpose
    tags         = output_array.first
    data         = output_array[1..-1]
    data.each {|values|
      xml << "  <record>\n"
      values.each_with_index {|value,i| 
        xml << "    <#{tags[i]}>#{value}</#{tags[i]}>\n"
      }
      xml << "  </record>\n"
    }
    xml << "</" + @data_type + ">"
    xml
  end

  # Create files of types, that are allowed by ExtCsvExporter.to_string
  def to_file(file, filetype=nil)
    # Create the output directory
    dir      = File.dirname(File.expand_path(file))
    FileUtils.mkdir_p(dir) unless File.directory?(dir)

    filename = File.directory?(file) ? DEFAULT_FILENAME : File.basename(file)
    filetype = File.extname(filename)[1..-1] if filetype.nil? or filetype.empty?
    File.open(file,"w") {|f|
      f << to_string(filetype)
    }
  end
end
