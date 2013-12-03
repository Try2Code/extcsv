$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'minitest/autorun'
require 'extcsv'
require 'extcsv_diagram'
require 'pp'

################################################################################
# Author:: Ralf Müller
################################################################################
class TestExtCsvDisplay < Minitest::Test
  include ExtCsvDiagram

  TEST_DIR        = "test"
  TEST_DATA       = TEST_DIR + "/data/file00.txt"
  TEST_DATA_NEW   = TEST_DIR + "/data/file01.txt"
  DATALOGGER_DATA = TEST_DIR + ""
  IMPORT_TYPE     = "file"
  ICON = "/home/ram/src/git/icon/experiments/xom.r8563.tsrel_R2B02_linDesity/xomFldminT.dat"
  ICON = "/home/ram/src/git/icon/experiments/xom.r8563.tsrel_R2B02_200mThickness/xomFldmin.dat"
  ICON = "/home/ram/src/git/icon/experiments/xom.r8563.tsrel_R2B02_500mThickness/xomFldmin.dat"
  ICON = "/home/ram/src/git/icon/experiments/xom.r8563.tsrel_R2B02/xomFldmaxVert_Mixing_V.dat"
  ICON = "/home/ram/src/git/icon/experiments/xom.r8563.tsrel_R2B02_200mThickness/xomFldmaxVert_Mixing_V.dat"
  ICON = "/home/ram/src/git/icon/experiments/xom.r8563.tsrel_R2B02_500mThickness/xomFldmaxVert_Mixing_V.dat"
  ICON = "/home/ram/src/git/icon/experiments/xom.r8563.tsrel_R2B02_dev/xomFldmaxVert_Mixing_V.dat"
  ICON = "/home/ram/src/git/icon/experiments/xom.r8563.tsrel_R2B02_dev/xomFldmaxT.dat"
  VAR = "Vert_Mixing_Vel"
  VAR = "Vert_Mixing_V"
  VAR = "T"

  def test_simple
    f=ExtCsv.new("file","txt",TEST_DATA)
    ExtCsvDiagram.plot_xy(f,"col5","col3",'',:groupBy => ['col2']) #,"col0",["col1"])
  end
  def test_colors
    pp ExtCsvDiagram.colors(21)
  end
  def _test_icon
    icon = ExtCsv.new(IMPORT_TYPE,"psv",ICON)

    icon.datetime = []
    icon.date.each_with_index{|date,i| icon.datetime << [date,icon.time[i]].join(' ') }

    puts "SIZE: #{icon.size}"
    [:date,:time,:depth,VAR.downcase.to_sym].each {|col| puts [col.to_s,icon.send(col).max].join('[max]: ') }
    ExtCsvDiagram.plot_xy(icon,"datetime",VAR.downcase,'ICON OCE_BASE: Mean. Temperatur (uneven levels, r8656, full run: 2001-2012)',
                       :label_position => 'below',:skipColumnCheck => true,
                         :type => 'lines',:groupBy => ["depth"],
#                         :yrange => '[0.0001:10]',
#                         :xrange => "",
                         :onlyGroupTitle => true,
#                         :addSettings => ["logscale y"],
#                         :terminal => "png",
                         :ylabel => "#{VAR} [degC]",
                         :input_time_format => "'%Y%m%d %H:%M:%S'",
                         :filename => "icon-OCE_BASE_uneven-r8656-fullrun-Mean#{VAR}",
                         :output_time_format => "'%m.%y'",:size => "800,600")

  end
  def test_plotxy
    f = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA)
    ExtCsvDiagram.plot_xy(f,"step","col5",'test',
                       :label_position => 'outside',
                       :groupBy => [:col4],
                         :type => 'lines')
    f = ExtCsv.new('file',"txt","#{ENV['HOME']}/data/icon/oce.txt")

    f.add(:datetime,[f.date,f.time].transpose.map {|v| v.join(' ')})
    pp f.datetime
    ExtCsvDiagram.plot_xy(f.selectBy(:level => 3000),'datetime',
                          'temp','icon text input',
                          :input_time_format => "'%Y-%m-%d %H:%M:%S'",
                          :output_time_format => "'%d.%m'")
  end
  def test_gnuplot
    test_file = TEST_DATA
    drift_test_file = TEST_DATA_NEW
    qpol = ExtCsv.new(IMPORT_TYPE,"txt",test_file)
    qpol_drift = ExtCsv.new(IMPORT_TYPE,"txt",drift_test_file)

    f = qpol.selectBy(:col4 => /(5|4)/)
    assert_not_equal(0,f.size)
    ExtCsvDiagram.plot(f,["col4"],"col1",
                       ["col5"],nil,[],'',
                       :graph_title => "SIZEMODE",
                       :point_label? => true,
                       :label_positions => 'outside',
                       :dataset_title => 'notitle',
                       :mode => "size"                       )
   f = qpol_drift.selectBy(:col4 => 5)
    f.plot([],"zeit",["col6"],:type => 'lines')
    qpol.plot([],
      "step",
      ["col7","col8"],
      {
      :point_label? => true,
      :xrange => "[0:1200]",
      :label_position => "right",
      :datasets => {:using => [nil,'1:($2*10)']},
      :graph_title => "USING-TEST",
      :mode => "qp" })
#   qpol_drift.selectBy(:focus => "5").plot(["zeit","zeit"],
#                                           ["iqa","iqc"],
#                                           {
#     #:yrange => "[0.7:1.4]",
#     :graph_title => "Multi-Graph",
#     :mode => "multi",
#     :label_column => "col5",
#     :point_label? => true,
#     :time_format => "'%H:%M'"
#   })
#   qpol.selectBy(:col2 => "5",:col4 => "120").operate_on(:col1,"*rand(10.0)").operate_on(:x2,"*10.2*rand(1.0)").operate_on(:z1,"/rand(8.0)").operate_on(:z2,"*rand(10.0)").plot(["col1","col2"],["col1","col2"],
#                                                                                                                                                                                      :graph_type => 'vectors',
#                                                                                                                                                                                      :mode => "multi",
#                                                                                                                                                                                      :arrowstyle => " arrow 1 head filled size screen 0.2, 30, 45 ",
#                                                                                                                                                                                      :linewidth => "1",
#                                                                                                                                                                                      #:linetype => "rgb '#ffee33'",
#                                                                                                                                                                                      :dataset_title => ["t3","t1"],
#                                                                                                                                                                                      :drawBox => "0,0,5,5,gray,1",
#                                                                                                                                                                                      :drawCurve => "1,1,6,6,blue,2",
#                                                                                                                                                                                      :graph_title => "Multi-Vectors"
#                                                                                                                                                                                     ) #if false
  end
  def test_extcsv_diagram_limits
    td = ExtCsv.new("file","txt",TEST_DATA_NEW)
    td.add(:step,(1...td.size).to_a)
    ExtCsvDiagram.plot(td[0,21],
                       ["col1"],
                       :step,
                       ["col3"],
                       "step",
                       ["col8"],
                       'limit test',
                       :y1limits       => [1.9],
                       :y1limitname    => "y1 Limit",
                       :y2limits       => [8.2],
                       :y2limitname    => "y2 Limit",
                       :xlabel         => "index",
                       :ylabel         => "YLabel",
                       :y2label        => "'Y2Label'",
                       :label_position => "out horiz bot",
                       :time_format    => "'%H:%M'",
                       :linewidth      => 1)
  end
end
