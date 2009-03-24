require 'rbgsl'
require 'mathn'

class SpectralFilter
  attr_accessor :x,:y,:fft,:sampling

  # x and y can be Arrays of Floats or GSL:Vectors. The sampling attribute
  # should be checked and changed carefully if necessary.
  def initialize(x, y)
    @x, @y    = [x,y].collect {|v| v.kind_of?(Array) ? GSL::Vector.alloc(v) : v}
    @sampling = ((@x[-1]-@x[0])/@x.size)**(-1)
    @fft      = @y.fft
  end

  # Frequences larger than freq are omitted
  def lowpass(freq)
    n=@y.size
    (0...n).each {|i| @fft[i] = 0 if i*(0.5/(n*(@x[1]-@x[0]))) > freq}
  end

  # Frequences smaller than freq are omitted
  def highpass(freq)
    n=@y.size
    (0...n).each {|i| @fft[i] = 0 if i*(0.5/(n*(@x[1]-@x[0]))) < freq}
  end

  # Frequences outside the range between freqMin and freqMax are subpressed
  def bandpass(freqMin,freqMax)
    n=@y.size
    (0...n).each {|i| 
      freq_   = i*(0.5/(n*(@x[1]-@x[0])))
      @fft[i] = 0 if (freq_ < freqMin or freq_ > freqMax)
    }
  end

  # Frequences in the range between freqMin and freqMax are omitted
  def bandblock(freqMin,freqMax)
    n=@y.size
    (0...n).each {|i| 
      freq_   = i*(0.5/(n*(@x[1]-@x[0])))
      @fft[i] = 0 if !(freq_ < freqMin or freq_ > freqMax)
    }
  end

  # reset the FFT to the initial state
  def renew
    @fft = @y.fft
  end

  # Display the spectrum
  def plotSpec(opts="-C -g 3 -x 0 #{@sampling/2} -X 'Frequency [Hz]'")
    mag, phase, frq = proc4plot
    GSL::graph(frq, mag, opts)
  end

  # Display Datasets before and aftern Filtering
  def plotData(opts="-C -g 3")
    GSL::graph(@x,@y,           opts  + " -L 'Original Data'")
    GSL::graph(@x,@fft.inverse, opts + " -L 'After Filtering'")
  end

  # little helper method for plotting
  def proc4plot
    y     = @fft.subvector(1, @y.size-2).to_complex2
    mag   = y.abs
    phase = y.arg
    frq   = GSL::Vector.linspace(0, @sampling/2, mag.size)
    [mag,phase,frq]
  end

  private :proc4plot
end

