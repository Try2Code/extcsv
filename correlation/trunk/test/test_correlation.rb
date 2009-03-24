$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'correlation'
require 'pp'

class TestCorrelation < Test::Unit::TestCase
  def test_simple
     v = GSL::Vector.alloc([0,1,0,0,0,0,0,0,0,0])
     w = GSL::Vector.alloc([0,0,0,0,0,0,0,0,1,0])
     
     #GSL::graph(v.correlation(w), "-X 'Correlation v with w' -C -g 3")
     #GSL::graph(v.autocorrelation,"-X 'Autocorrelation v' -C -g 3")

     assert_equal(1, v.correlation(w)[1][-3])
     assert_equal(0, v.correlation(w)[1][9])

     assert_equal(1,v.autocorrelation[1][v.autocorrelation[0].where {|i| i == 0}[0]])
     assert_equal(0,v.autocorrelation[1][v.autocorrelation[0].where {|i| i != 0}[0]])
  end
end
