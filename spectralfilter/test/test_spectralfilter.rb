$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'spectralfilter'

class TestSpectralFilter < Test::Unit::TestCase
  N = 2048
  SAMPLING = 2000   # 2 kHz
  TMAX = 1.0/SAMPLING*N
  FREQ1 = 50
  FREQ2 = 120
  FREQ3 = 500
  FREQ4 = 550
  def test_simple
    t = GSL::Vector.linspace(0, TMAX, N)
    x = GSL::Sf::sin(2*Math::PI*FREQ1*t) + \
        GSL::Sf::sin(2*Math::PI*FREQ2*t) + \
        GSL::Sf::sin(2*Math::PI*FREQ3*t) + \
        GSL::Sf::sin(2*Math::PI*FREQ4*t)

    sf = SpectralFilter.new(t,x)
    opts ="-C -g 3 -x 0 700 "
    sf.plotSpec(opts + "-L'Original Data'")
    sf.lowpass(60)
    sf.plotSpec(opts + "-L 'lowpass(60)'")
    sf.renew
    sf.highpass(450)
    sf.plotSpec(opts + "-L 'highpass(450)'")
    sf.renew
    sf.bandpass(100,520)
    sf.plotSpec(opts + "-L 'bandpass(100,520)'")
    sf.renew
    sf.bandblock(100,520)
    sf.plotSpec(opts + "-L 'bandblock(100,520)'")
  end
end
