$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'extcsv'
require 'extcsv_diagram'
require 'pp'

################################################################################
# Author:: Ralf Müller
################################################################################
class TestExtCsvDisplay < Test::Unit::TestCase
#  include ExtCsvDiagram

  TEST_DIR        = "test"
  TEST_DATA       = TEST_DIR + "/data/file00.txt"
  TEST_DATA_NEW   = TEST_DIR + "/data/file01.txt"
  DATALOGGER_DATA = TEST_DIR + ""
  IMPORT_TYPE     = "file"

   def test_gnuplot
     test_file = TEST_DIR + ""
     drift_test_file = TEST_DIR + ""
     qpol = ExtCsv.new(IMPORT_TYPE,"txt",test_file)
     qpol_drift = ExtCsv.new(IMPORT_TYPE,"txt",drift_test_file)
     qpol.select_by(:col1 => "(5|4)").gnuplot("col1",
                                           ["col2"],
                                           :graph_title => "SIZEMODE",
                                           :point_label? => true,
                                           :label_positions => 'outside',
                                           :dataset_title => 'notitle',
                                           :mode => "size",
                                           :xrange => "[1.0:1.4]",
                                           :yrange => "[1.0:1.4]"
                                          )
     qpol.select_by(:col1 => 5).gnuplot("zeit",["col2"],:mode => "drift")
     qpol.select_by(:col1 => "5").gnuplot("col3",
                                           ["col7","col8"])
     qpol.select_by(:col2 => "5",:col3 => "(140|80)").gnuplot(
          "col4",
          ["col7","col8"],
          {
            :point_label? => true,
            :xrange => "[0:1200]",
            :label_position => "right",
            :datasets => {:using => [nil,'1:($2*10)']},
            :graph_title => "USING-TEST",
            :mode => "qp"
          }
        )
     qpol_drift.select_by(:col2 => "5").gnuplot(
       "zeit",
       ["col2","col3"],
       {
         :yrange => "[0.7:1.4]",
         :graph_title => "Plotted from one File",
         :mode => "drift",
         :time_format => "'%H:%M'"
       }
     )
     qpol_drift.select_by(:focus => "5").gnuplot(["zeit","zeit"],
                                           ["iqa","iqc"],
                                           {
                                             #:yrange => "[0.7:1.4]",
                                             :graph_title => "Multi-Graph",
                                             :mode => "multi",
                                             :label_column => "col5",
                                             :point_label? => true,
                                             :time_format => "'%H:%M'"
                                           })
    qpol_drift.select_by(:col2 => "5",:col4 => "120").operate_on(:col1,"*rand(10.0)").operate_on(:x2,"*10.2*rand(1.0)").operate_on(:z1,"/rand(8.0)").operate_on(:z2,"*rand(10.0)").gnuplot(["col1","col2"],["col1","col2"],
                                                :graph_type => 'vectors',
                                                :mode => "multi",
                                                :arrowstyle => " arrow 1 head filled size screen 0.2, 30, 45 ",
                                                :linewidth => "1",
                                                #:linetype => "rgb '#ffee33'",
                                                :dataset_title => ["t3","t1"],
                                                :drawBox => "0,0,5,5,gray,1",
                                                :drawCurve => "1,1,6,6,blue,2",
                                                :graph_title => "Multi-Vectors"
                                               ) #if false
   end
   def test_ExtCsv_gnuplot
     test_data       = TEST_DIR + ""
     test_data = TEST_DIR + ""
     qpol = ExtCsv.new(IMPORT_TYPE,"txt",TEST_DATA).select_by(:col3 => "5",
                                                              :col2 => "100")
     qpol_ = ExtCsv.new(IMPORT_TYPE,"txt",test_data).select_by(:col3 => "5",
                                                               :col2 => "100")
      ExtCsv.gnuplot([qpol,qpol_],
                       ["9416 Gen1","9416 Gen3"],
                       "col1",
                       ["col7","col8"])
      ExtCsv.gnuplot([qpol,qpol_],
                       ["9416 Gen1","9416 Gen3"],
                       "col1",
                       ["col5"])
   end
 
   def _test_gnuplot_with_combined_qpols
     qpols_const = []
     qpols_kv_const = []
     qpols_ = []
     # mA = const
     drift_files = [ "test/data/file02.txt" , "test/data/file03.txt"]
     drift_files.each {|dfile|
       qpols_const << ExtCsv.new(IMPORT_TYPE,"txt",dfile).selectBy(:col4 => "5")
     }
     
     ExtCsv.gnuplot(qpols_const,
                      ["Title0","Title1","Title2"],
                      "zeit",
                      ["col8","col7"],
                      {:graph_type => "points",
                       :graph_title => "Display more than one ExtCsv object"}
                     )
     qpol = ExtCsv.concat(*qpols_ma_const)
     qpol.gnuplot("zeit",
                  ["col2","col2"],
                  { :mode => "drift",
                    :yrange => "[0.7:1.4]",
                    :graph_title => "Plotted from a combined Object: col2 = const"
                  }
                 )
   end
   
   def test_tube_diagram_labels
     erg_csv = ExtCsv.new("file","txt",TEST_DATA_NEW)[0..10]
     ExtCsvDiagram.plot(erg_csv,[],:col2,[:col7,:col8],'',[],'',:point_label? => true,:label_column => :string)
   end
   def test_extcsv_diagram_limits
     td = ExtCsv.new("file","txt",TEST_DATA_NEW)
     ExtCsvDiagram.plot(td[0,21],
                        [:col1],
                        :index,
                        [:col3],
                        :zeit,
                        [:col8],
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
