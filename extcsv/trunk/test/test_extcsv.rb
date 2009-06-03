$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'extcsv'
require 'fileutils'
require 'pp'
include FileUtils::Verbose

################################################################################
# Author:: Ralf Müller
################################################################################
class ExtCsv
  def setmode(mode)
    @mode = mode
  end
  public :deep_split
end

class TestExtCsv < Test::Unit::TestCase
  TEST_DIR        = "test/"
  TEST_DATA_DIR   = TEST_DIR + "data/"
  TEST_DATA       = TEST_DIR + "data/file00.txt"
  TEST_DATA_NEW   = TEST_DIR + "data/file01.txt"
  TEST_FD_DATA    = TEST_DATA_NEW
  ERG_CSV_DATA    = TEST_DIR + "data/file04.csv"
  ERG_CSV_DATA_    = TEST_DIR + "data/file05.csv"
  ERG_CSV_DATA.freeze
  TEST_OUTOUT_DIR = TEST_DIR + "output"
  IMPORT_TYPE     = "file"
  def test_create
    test_simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    assert_equal("txt",test_simple.datatype)
  end
  def test_create_csv
    test_simple = ExtCsv.new(IMPORT_TYPE,"ssv",ERG_CSV_DATA)
  end
  def test_create_by_hash
    simple = ExtCsv.new("hash","txt",{:col1 => ["80.0"],:col2 => ["625.0"]})
    assert_equal(["80.0"],simple.col1)
    assert_equal(["625.0"],simple.col2)
  end
  def test_create_by_string
    str = File.open(TEST_DATA).read
    td_by_str  = ExtCsv.new("string","txt",str)
    org = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    assert_equal(org.size,td_by_str.size)
    assert_equal(org.x2,td_by_str.x2)
  end
  def test_datasets
    test_simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    assert_equal(["100.0", "950.0"], test_simple.datasets("col1","col2")[29])
  end
  def test_csv
    test_simple = ExtCsv.new(IMPORT_TYPE,"ssv",ERG_CSV_DATA)
  end
  def test_selectBy_index
    test_simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    indexes = (0..4).to_a + (10..12).to_a + [15]
    simple_new =  test_simple.selectBy_index(indexes)
    assert(!simple_new.col4.empty?)
    assert_equal(test_simple.col4.values_at(*indexes), simple_new.col4)
  end
  def test_selectBy
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    assert_equal(ExtCsv, simple.selectBy(:col4 => "5").class)
    simple_col1 = simple.selectBy(:col1 => "120.0")
    assert_equal(["120.0"],simple_col1.col1.sort.uniq)
    simple_col1_num = simple.selectBy(:col1 => 120.0)
    assert_equal(["120.0"],simple_col1_num.col1.sort.uniq)
    assert(!simple_col1.col1.empty?)
    assert(!simple.col1.empty?)
    assert_not_equal(simple, simple_col1)

    # test datacolumns
    assert_equal([],simple.datacolumns - simple.selectBy(:col4 => "5",:col1 => "80.0",:col2 => "500.0").datacolumns)

    # numeric selection via string, numeric or regexp
    testobj = {}
    fd = ExtCsv.new(IMPORT_TYPE, "txt", TEST_FD_DATA )
    col2 = 50
    testobj[col2] = fd.selectBy(:col2 => col2).col2
    col2 = 50.0
    testobj[col2] = fd.selectBy(:col2 => col2).col2
    col2 = /50/
    testobj[col2] = fd.selectBy(:col2 => col2).col2
    col2="50"
    testobj[col2] = fd.selectBy(:col2 => col2).col2
    testobj.each {|col2,col2s|
      if col2 == /50/
        assert(col2s.sort.uniq.size > 1)
      else
        assert(col2s.sort.uniq.size == 1)
        assert(col2s.sort.uniq.include?("50.0"))
      end
    }

    # numeric comparison via numeric or string
    testobj = []
    col2 = '<= 500.0'
    size = 80
    testobj << [col2, fd.selectBy(:col2 => col2).col2, size]
    col2 = '<= "500.0"'
    size = 82
    testobj << [col2, fd.selectBy(:col2 => col2).col2, size]
    col2 = '> 500.0'
    size = 40
    testobj << [col2, fd.selectBy(:col2 => col2).col2, size]
    col2 = "> '500.0'"
    size = 38
    testobj << [col2, fd.selectBy(:col2 => col2).col2, size]
    col2 = '> "500.0"'
    size = 38
    col2 = "<= '500.0'"
    size = 82
    testobj << [col2, fd.selectBy(:col2 => col2).col2, size]
    testobj.each {|col2,col2s, s|
      #test $stdout << col2.inspect << "\t" << col2s.size.to_s << ":\t\t" + col2s.sort.uniq.join("\t") << "\n"
      assert_equal(s, col2s.size)
    }

    # String search
    testobj = {}
    size = fd.size
    string          = 'machine1'
    testobj[string] = fd.selectBy(:string => string).string
    string          = /machine/
    testobj[string] = fd.selectBy(:string => string).string
    string          = '> machine'
    testobj[string] = fd.selectBy(:string => string).string
    testobj.each {|an, ans|
      assert_equal(ans.size, size)
    }

    # time selection
    testobj = []
    time          = '2007-01-19 14:14:19'
    size          = 1
    testobj << [time, fd.selectBy(:zeit => time).zeit, size]
    time          = /14:14/
    size          = 1
    testobj << [time, fd.selectBy(:zeit => time).zeit, size]
    time          = "> '2007-01-19 14:14'"
    size          = 16
    testobj << [time, fd.selectBy(:zeit => time).zeit, size]
    time          = "<= '2007-01-19 14:14'"
    size          = fd.size - size
    testobj << [time, fd.selectBy(:zeit => time).zeit, size]
    testobj.each {|t, times, s|
      #test $stdout << t.inspect << "\t" << times.size.to_s << ":\t\t" + times.sort.uniq.join("\t") << "\n"
      assert_equal(s, times.size)
    }

    # > operation
    simple_large_col1 = simple.selectBy(:col1 => "> 120.0")
    assert_equal(["140.0"],simple_large_col1.col1.uniq)
    # < operation
    simple_scol2ll_col1 = simple.selectBy(:col1 => "< 120.0")
    assert_equal(["80.0","100.0"],simple_scol2ll_col1.col1.sort.uniq.reverse)
    assert(!simple_large_col1.col1.empty?)
    assert(!simple_scol2ll_col1.col1.empty?)
    # >= operation
    s = simple.selectBy(:col1 => ">= 120.0")
    assert_equal(["120.0","140.0"],s.col1.sort.uniq)
    # <= operation
    s = simple.selectBy(:col1 => "<= 120.0")
    assert_equal(["80.0","120.0","100.0"],s.col1.uniq.sort.reverse)
    # == operation
    s = simple.selectBy(:col1 => "== 120.0")
    assert_equal(["120.0"],s.col1.sort.uniq)
    # != operation 
    s = simple.selectBy(:col1 => "!= 120.0")
    assert_equal(false, s.col1.collect {|v| v.to_f}.include?("120.0"))
  end
  def test_multiple_select
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    s_col1 = simple.selectBy(:col1 => "120")
    s_col2 = simple.selectBy(:col2 => "600")
    s_col1col2 = simple.selectBy(:col1 => "120",:col2 => "600")
    s_col1_col2 = simple.selectBy(:col1 => "120").selectBy(:col2 => "600")
    assert(!s_col1col2.empty?)
    assert(!s_col1_col2.empty?)
    assert_equal(s_col1col2.size, s_col1_col2.size)
    assert_equal(s_col1col2, s_col1_col2)
    assert_equal(s_col1col2.x2, s_col1_col2.x2)
  end
  def test_improved_selection
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_NEW)
    s_zeit = simple.selectBy(:zeit => "< '2007-01-17 15:34:33'")
    assert_equal("2007-01-17 15:34:21",s_zeit.zeit.max)
    assert_equal(2,s_zeit.size)
    s_col1_col2_foc = simple.selectBy(:col1 => "120",:col2 => "600",:col4 => "5")
    assert_equal(1,s_col1_col2_foc.size)
    # test regexp
    s_foc_regexp = simple.selectBy(:col4 => "(4|5)")
  end
  def _test_method_response
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_NEW)
    simple.respond_to?(:selectBy)
  end

  def test_split
    test = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    col4 = test.col4.dup
    test_col4 = []
    assert_equal(test.split(:col1,:col4).size, test.split(:col4,:col1).size)
    test.split(:col1, :col2,:col4) {|qp| test_col4 << qp.col4.first}
    assert_equal(114,test_col4.size)
    assert_equal([], test_col4 - col4)
    test_c= []
    test.split(:col4) {|qp| test_c << qp.col4[0]}
    assert_equal(["4","5"], test_c.uniq.sort)
    assert_equal([test],test.split())
  end
  def test_deep_split
    retval = []
    test = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    test.deep_split([:col1],retval)
    assert_equal(4,retval.size)
    retval = []
    test.deep_split([:col1,:col4],retval)
    assert_equal(8,retval.size)
    retval = []
    test.deep_split([:col1,:col4,:col2],retval)
    assert_equal(114,retval.size)
  end
  def test_clear
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    assert_equal(false, simple.col1.empty?)
    simple.clear
    assert(simple.col1.empty?)
    assert(simple.empty?)
  end
  def test_each_by
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    testary = []
    simple.each_by(:col1) do |k| testary << k; end
    assert_equal(["100.0","120.0","140.0","80.0"],testary)
  end
  def test_each_obj
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    testary = []
    simple.each_obj(:col1) do |obj| testary << obj.col1[0]; end
    assert_equal(["100.0","120.0","140.0","80.0"],testary)
    testary = []
    simple.each_obj(:col4) do |obj| testary << obj.col4[0]; end
    assert_equal(["4","5"],testary)
  end
  def test_operate
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    simple_operated  = simple.operate_on(:col1,"* 10")
    assert_not_equal(simple.col1, simple_operated)
    thiscol1 = 80.0
    col1s = simple.col1.dup
    simple_op_with_ifclause = simple.operate_on(:col1, '* 10 if self.col1[i].to_f == ' + thiscol1.to_s)
    assert_equal(col1s, simple.col1)
    assert_equal([100,120,140,800],simple_op_with_ifclause.col1.uniq.collect {|k| k.to_i}.sort)
    simple.operate_on!(:col1, '* 10 if self.col1[i].to_f == ' + thiscol1.to_s)
    assert_equal([100,120,140,800],simple.col1.uniq.collect {|k| k.to_i}.sort)
  end
  def test_operate_percol2nent
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
  end
  def test_operateANDselect
    simple             = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    simple_foc         = simple.selectBy(:col4 => "5")
    simple_foc_changed = simple.selectBy(:col4 => "5").operate_on(:col1,"* 10")
    assert_equal(ExtCsv, simple_foc_changed.class)
    simple_changed     = simple.operate_on(:col1,"* 10")
    assert_equal(ExtCsv, simple_changed.class)
  end
  def test_set
    simple     = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA).selectBy(:col4 => 5)
    col1_changed = simple.set_column(:col1,"10")
    assert_not_equal(simple.col1, col1_changed.col1)
    assert_equal(["10"], col1_changed.col1.uniq)
    simple.set_column!(:col1,"10")
    assert_equal(["10"], simple.col1.uniq)
    simple.operate_on!(:col1, "* #{Math::PI}")
    assert_equal(["31.4159265358979"],simple.col1.uniq)
  end
  def test_emptyness
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    assert_equal(false,simple.empty?)
    empty = ExtCsv.new("hash","txt",{})
    assert_equal(true,empty.empty?)
    empty = ExtCsv.new("hash","txt",{:col1 => []})
    assert_equal(true,empty.empty?)
  end
  def test_size
    obj = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    assert_equal(114,obj.size)
    assert_equal(obj.size, obj.col1.size)
    obj = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_NEW)
    assert_equal(120,obj.size)
    assert_equal(obj.size, obj.col1.size)
  end
  def test_ClassMethod_concat
    obj0 = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    obj1 = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    obj2 = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_NEW)
    assert(!obj2.empty?)
    assert_equal(ExtCsv.concat(obj0, obj1),ExtCsv.concat(*[obj0, obj1]))
    newobj01 = ExtCsv.concat(obj0, obj1)
    assert_equal(228,newobj01.size)
    obj0.delete_field(:step)
    obj2.delete_field(:step)
    #pp obj0.rsize
    #pp obj2.rsize
    newobj02 = ExtCsv.concat(obj0, obj2)
    #puts
    #pp newobj02.rsize
    #pp newobj02.csize
    #pp newobj02.size
    #newobj02.datacolumns.each {|c| p c + " " + newobj02.send(c).size.to_s}
    #assert_equal(120,newobj02.size)
    #assert_equal(120,newobj02.rsize)
  end
  def test_splitting_with_strings
    qp = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    assert_equal(qp.each_obj(:col1), qp.each_obj("col1"))
    assert_equal(4,qp.each_obj("col1").size)
    assert_equal(qp.split(:col1,:col4),qp.split("col1","col4"))
  end
  def test_deep_equality
    f1  = 'file02.txt'
    f2  = 'file03.txt'
    t1  = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR + f1)
    t1_ = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR + f1)
    t2  = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR + f2)
    qp  = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    assert_equal(false, t1 == t2)
    assert_equal(true,  t1.eql?(t2))

#   t2.col1.collect! {|v| v.to_f + 2.0}
#   assert_equal(false, t1==t2)
#   assert_equal(false, t1.eql?(t2))
#   t2.col1.collect! {|v| v.to_f - 2.0}
#   assert_equal(false, t1 == t2)
#   assert_equal(true, t1.eql?(t2))
#   ###########################
#   assert_equal(false, t1==qp)
#   assert_equal(false, t1.eql?(qp))
#   assert_equal(qp.eql?(t1), t1.eql?(qp))
#   ###########################
#   assert_equal(true, t1 == t1_)
#   assert_equal(true, t1.eql?(t1_))
#   assert_equal(false, t1.equal?(t1_))
#   t1_.filename = ""
#   assert_equal(false, t1 == t1_)
#   assert_equal(true, t1.eql?(t1_))
  end
  def test_compare
    # f1 was written by excel => file contains timestamps without seconds. i.e.
    # is scol2ller than f2
    f1 = 'file02.txt'
    f2 = 'file03.txt'
    t1  = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR+f1)
    t1_ = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR+f1)
    t2  = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR+f2)
    qp  = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    #########################
    assert_equal(f2,File.basename([t2,t1].max.filename))
    #########################
    assert_respond_to(t1,"<")
    assert_respond_to(t1,"<=")
    assert_respond_to(t1,">")
    assert_respond_to(t1,">=")
    assert_respond_to(t1,"==")
    assert_respond_to(t1,"between?")
    assert_equal(true,t1 <= qp)
    assert_equal(true,t1 < qp)
    assert_equal(true,t1 < t2)
    assert_equal(t2.size <=> qp.size,t2 <=> qp)
    ##########################
    assert_equal(true,t1 <= t1)
    assert_equal(true,t1 >= t1)
    assert_equal(true,t1 == t1)
    assert_equal(true,t1 == t1_)
    assert_equal(true,t1.eql?(t1_))
    t1_.filename=''
    t1_.zeit[0]='' if t1_.respond_to?(:zeit)
    assert_equal(false,t1 == t1_)
    assert_equal(true,t1.eql?(t1_))
    t1_.col1[0]=''
    assert_equal(false,t1 == t1_)
    assert_equal(false,t1.eql?(t1_))
    ##########################
    assert_equal(true,t1 <= t2)
    assert_equal(t1 <= t2, t1.to_s <= t2.to_s)
    t1.zeit.each_index {|i| t1.zeit[i] = t1.col1.to_s} if t1_.respond_to?(:zeit)
    assert_equal(true,t1 > t2) if t1_.respond_to?(:zeit)
  end
  def test_uniq
    f1 = 'file02.txt'
    f2 = 'file03.txt'
    t1  = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR+f1)
    t1_ = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR+f1)
    t2  = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR+f2)
    qp  = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    tds = [t1,t2,qp,t1_,t2]
    # tds = [t1,t1_,t1__,t1___]
    # tds.each {|td| puts [td.filename,td.hash].join("\t")}
    # tds.each {|td| puts [td.filename,td.object_id].join("\t"); puts tds.collect {|x| "#{x.object_id.to_s}: #{td.eql?(x).to_s}"}.join("\t")}
    # puts '################################################################################'
    # tds.each {|td| puts [td.filename,td.object_id].join("\t"); puts tds.collect {|x| "#{x.object_id.to_s}: #{(td==(x)).to_s}"}.join("\t")}
    # puts '################################################################################'
    # tds.reverse.uniq.each {|td| 
    #   puts [td.filename,td.object_id].join("\t")
    # }
    # puts tds.uniq.collect{|m| m.filename}.join(" ")
    assert_equal(3,tds.uniq.size)
    assert_equal([t1,t2,qp],tds.uniq)
  end
  def test_combine
    f1 = 'file02.txt'
    f2 = 'file03.txt'
    csv   = ExtCsv.new(IMPORT_TYPE,"ssv",ERG_CSV_DATA)
    t2    = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR+f2)
    t1    = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR+f1)

    minsize = [csv.rsize,t1.rsize].min - 1
    csv   = ExtCsv.new(IMPORT_TYPE,"ssv",ERG_CSV_DATA)[0..minsize]
    csv_   = ExtCsv.new(IMPORT_TYPE,"csv",ERG_CSV_DATA_)[0..minsize]
    t2    = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR+f2)[0..minsize]
    t1    = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA_DIR+f1)[0..minsize]
    t1csv = t1 & csv
    csvt1 = csv & t1
    csvcsv = csv & csv
    csvcsv_ = csv_ & csv_
    csvcsvcsv = csv & csv & csv
    csvt1csv = csv & t1 & csv
    td    = ExtCsv.combine(t1,t2)
    td_   = ExtCsv.combine(*[t1,t2])
    td12  = t1.combine(t2)
    td21  = t2.combine(t1)
    td21_ = t2 & t1
    #[t1,t2,td12,td21,csv,t1csv,csvt1,csvcsv,csvcsvcsv,csvt1csv].each {|tt| puts tt.rsize}
    assert_equal(td.to_s,td_.to_s)
    assert_equal(td,td_)
    #TODO: csv vs. ssv 
    #puts csv.datacolumns.sort
    #puts "#############"
    #puts csv_.datacolumns.sort
#    compare =   (csv.datasets(* csv.datacolumns.sort).to_s <=> csv_.datasets(* csv.datacolumns.sort).to_s) if compare.zero?
    #assert_equal(csv.datasets(* csv.datacolumns.sort).to_s,    csv_.datasets(* csv.datacolumns.sort).to_s)
    #assert_equal(td.datasets(* td.datacolumns.sort).to_s,td_.datasets(* td.datacolumns.sort).to_s)
    #assert_equal(csv.to_s,csv_.to_s)
    assert_equal(csv.datasets(* csv.datacolumns.sort).to_s,    csv_.datasets(* csv.datacolumns.sort).to_s)
    #return
    
    #assert_equal(csvcsv,csvcsv_)
    assert_equal(td,ExtCsv.combine(*[td]))
    assert(td == td12)
    assert(td21_.eql?(td12),"combination by instance method('&')")
    assert(td21.eql?(td12), "combination by instance method('combine')")
    assert(t1, t1.combine(t1))
    assert(csv, csv.combine(csv))
    assert_equal(t1.combine(t2), t1 & t2)
    assert_not_equal(t2 & t1, t1 & t2)
    assert(csv & t1, t1 & csv)
    assert_equal(t1.rsize,td.rsize)
    assert_equal(t1.rsize,td12.rsize)
    assert_equal(t1.rsize,td21.rsize)
    assert_equal(t1csv, csvt1)
    assert(t1csv == csvt1)
    assert(t1csv.eql?(csvt1))
    assert_not_equal(csvcsvcsv,csvt1csv)
    cols = [:filename, :filemtime]
    #[t1,t2,td12,td21].each {|t| cols.each {|col| puts [col, t.send(col).to_s].join("\t")}; puts '#####################'}
  end
  def test_range
    simple = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    range = (0...12)
    index = -5
    start ,length = 0,12
    assert_equal( simple.col4[range], simple[range].col4)
    assert_equal( simple.col4[start,length], simple[start,length].col4)
    assert_equal( [simple.col4[index]], simple[index].col4)
    assert_equal( simple.col4[range], simple[start,length].col4)
    assert_equal(1,simple[0].rsize)
  end
  def test_concat
    simple0 = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    simple1 = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    csv   = ExtCsv.new(IMPORT_TYPE,"ssv",ERG_CSV_DATA)
    simpleconcat = ExtCsv.concat(simple0,simple1)
    assert_equal(simple0.concat(simple1),ExtCsv.concat(simple0,simple1))
    assert_equal(simple0.rsize + simple1.rsize, (simple0 + simple1).rsize)
    assert_equal(csv.rsize + csv.rsize, ExtCsv.concat(csv,csv).rsize)
    assert_equal(simple0.rsize*2, simple0.concat(simple1).rsize)
    assert_equal(simple0 << simple1, simpleconcat)
    #assert_equal(["2009-03-21 23:53:24"]*2,(simple0 << simple1).filemtime)
    assert_equal(simple0 + simple1, simpleconcat)
    # concatenation of different datatypes is not permitted
    assert_nil(simple0 + csv)
    assert_nil(csv + simple0)
  end
  def test_version
    assert_equal('0.10.0',ExtCsv::VERSION)
  end

  def test_add
    simple = ExtCsv.new(IMPORT_TYPE, "txt", TEST_FD_DATA )
    simple.add("test",[nil]*4)
    assert_equal([nil]*4,simple.test)
  end

  def test_closest_to
    simple = ExtCsv.new(IMPORT_TYPE, "txt", TEST_FD_DATA )
    assert_equal(600,simple.closest_to(:col2 ,601).col2[0].to_i)
  end

  def test_umlaut
    simple = ExtCsv.new(IMPORT_TYPE, "txt", "german.txt")
    pp simple
  end
end
