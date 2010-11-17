$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'correlation'
require 'pp'

class TestCorrelation < Test::Unit::TestCase
  def test_simple
     v = GSL::Vector.alloc([0,1,0,0,0,0,0,0,0,0])
     w = GSL::Vector.alloc([0,0,0,0,0,0,0,0,1,0])
     
     GSL::graph(v, "-X 'v' -C -g 3")
     GSL::graph(w, "-X 'w' -C -g 3")
     GSL::graph(v.correlation(w), "-X 'Correlation v with w' -C -g 3")
     GSL::graph(v.autocorrelation,"-X 'Autocorrelation v' -C -g 3")

     cor = v.correlation(w)

     pp v.correlation(w)[0].to_a
     pp v.correlation(w)[1].to_a
     assert_equal(20,cor[1].size)
     assert_equal(1, v.correlation(w)[1][-3])
     assert_equal(0, v.correlation(w)[1][9])
  end
end
