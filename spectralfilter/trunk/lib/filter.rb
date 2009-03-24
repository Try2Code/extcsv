require 'rbgsl'
require 'mathn'

class SpectralFilter
  attr_accessor :x,:y,:fft,:sampling

  # _x_ and _y_ can be Array of Floats or GSL:Vector
  def initialize(x, y)
    @x, @y    = [x,y].collect {|v| v.kind_of?(Array) ? GSL::Vector.alloc(v) : v}
    @sampling = ((@x[-1]-@x[0])/@x.size)**(-1)
    @fft      = @y.fft
  end

  def lowpass(freq)
    n=@y.size
    (0...n).each {|i| @fft[i] = 0 if i*(0.5/(n*(@x[1]-@x[0]))) > freq}
  end
  def highpass(freq)
    n=@y.size
    (0...n).each {|i| @fft[i] = 0 if i*(0.5/(n*(@x[1]-@x[0]))) < freq}
  end
  def bandpass(freqMin,freqMax)
    n=@y.size
    (0...n).each {|i| 
      freq_   = i*(0.5/(n*(@x[1]-@x[0])))
      @fft[i] = 0 if (freq_ < freqMin or freq_ > freqMax)
    }
  end
  def bandblock(freqMin,freqMax)
    n=@y.size
    (0...n).each {|i| 
      freq_   = i*(0.5/(n*(@x[1]-@x[0])))
      @fft[i] = 0 if !(freq_ < freqMin or freq_ > freqMax)
    }
  end

  def renew
    @fft = @y.fft
  end

  def plotSpec(opts="-C -g 3 -x 0 #{@sampling} -X 'Frequency [Hz]'")
    mag, phase, frq = proc4plot
    GSL::graph(frq, mag, opts)
  end
  def plotData(opts="-C -g 3 -L 'After Filtering'")
    GSL::graph(@x,@fft.inverse, opts)
    GSL::graph(@x,@y, opts)
  end

  def proc4plot
    y     = @fft.subvector(1, @y.size-2).to_complex2
    mag   = y.abs
    phase = y.arg
    frq   = GSL::Vector.linspace(0, @sampling/2, mag.size)
    [mag,phase,frq]
  end
end

