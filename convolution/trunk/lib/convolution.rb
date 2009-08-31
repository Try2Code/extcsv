require 'rubygems'
require 'tube_data'
require 'tube_data_diagram'
require 'gsl'
require 'ostruct'
require 'arraylinspace'

class ConvolutionKernel
  attr_reader :ktype, :kwidth, :kpartition, :x, :w
  def initialize(ktype, kwidth, kpartition)
    @ktype      = ktype
    @kwidth     = kwidth.to_f
    @kpartition = kpartition.to_f
    @correction = 1.0

    @x, @w = case @ktype
    when "lin","linear"
      linkernel(@kwidth, @kpartition)
    when "exp","unit"
      unitkernel(@kwidth,@kpartition)
    else
      $stderr << "Use 'lin' or 'unit' type of kernel!\n"
      exit
    end
    # Integral correction
    if @ktype == "exp"
      @correction = 1/self.integral
      @x, @w = unitkernel(@kwidth,@kpartition)
    end
    # transform into GSL-DataType for performance
    @x, @w = GSL::Vector.alloc(@x), GSL::Vector.alloc(@w)
  end

  def integral
    @w.inject(0) {|sum,item| sum += item*(2*@kwidth/@kpartition)}
  end

  private
  def linkernel(width, partition)
    x     = Array.linspaceByPartition(-width,
                                      width,
                                      partition)
    w     = x.collect {|x_| -x_.abs/width**2 + 1/width}
    [x,w]
  end
  def unitkernel(width,partition)
    kernel_default(width, partition) 
  end
  def kernel_value(x)
    Math.exp(-1/(1-x.abs**2))
  end
  def kernel_weighted(width, x)
    kernel_value(x/width)/width * @correction
  end
  def kernel_default(width, partition)
    x     = Array.linspaceByPartition(-width,
                                      width,
                                      partition)
    w     = x.collect {|x_| kernel_weighted(width, x_)}
    [x,w]
  end
end

# Compute a discrete Convolution of the functions f and g
# Functions are expected to behave like relations, i.e.
# 
# function = OpenStruct.new({:x => [x0,...,xN],:y => [y0,...,yN]})
# 
module Convolution
#  def initialize(func_f, func_g)
#    @func_f = func_f
#    @func_g = func_g
#  end
  def fold(f,g,n)
    ret = 0
    g.x.each_with_index {|step,i|
      ret += f.y[n+step]*g.w[i] if (0..f.x.size-1).to_a.include?(n+step)
    }
    ret
  end
  def folding(f,g)
    ret = OpenStruct.new
    ret.x = f.x.to_a
    ret.y = []
    (0..f.x.size-1).each {|x_| ret.y << fold(f,g,x_)}
    ret
  end
  def conv(f,g)
    y = GSL::Vector.alloc(1)
    y.pop
    (0...f.x.size).each {|n| y << conv_step(f,g,n)}
    OpenStruct.new(:x => f.x.dup,:y => y)
  end
  def conv_step(f,g,n)
    ret = 0
    g.x.to_a.each_with_index {|step,i_step|
      index = n.to_i + step.to_i
      ret += f.y[index]*g.w[i_step] if ( index < f.x.size and index >= 0)
    }
    ret
  end
  def expand(vector,width)
    GSL::Vector.connect(vector[1..width].reverse,vector,vector[-(width+1)..-2].reverse)
  end
  def convolute(f,g)
    width = g.w.size/2.to_i
    conv = GSL::Vector.alloc(1)
    conv.shift
    fExp = expand(f.y,width)
    (width...fExp.size-width).each {|i| 
      conv << fExp[i-width..i+width]*g.w.col
    }
    OpenStruct.new(:x => f.x , :y => conv)
  end
  private :expand
end
module CPlot
  def plot_kernel(g)
    td = TubeData.new("hash","plain",{:x => g.x,:w => g.w})
    TubeDiagram.plot(td,[],:x,[:w])
  end
  def plot(f)
    td = TubeData.new("hash","plain",{c0.to_sym => f.send(c0),c1.to_sym => f.send(c1)})
    TubeDiagram.plot(td,[],:x,[:y],'',[],'',:linewidth => 1)#,:xrange => '[50:150]')
  end
  def CPlot.gplot(*datasets)
    require 'gnuplot'
    Gnuplot.open {|gp|
      Gunplot::Plot.new(gp) {|plot|
        datasets.each {|dataset|
          Gnuplot::DataSet.new(dataset) {|ds|
            ds.with 'lines'
          }
        }
      }
    }
  end
end
################################################################################
if __FILE__ == $0
  include Convolution
  bmax=GSL::Vector.linspace(1.2,1.2,100)
  bmin=GSL::Vector.linspace(1.0,1.0,100)
  x,int = GSL::Vector.filescan(ARGV[0])
  f=OpenStruct.new
  f.y = int
  f.x = x
  g=OpenStruct.new
  g.x = (-2..2).to_a
  g.w = [0,0.25,0.5,0.25,0]
  fold_f_g = folding(f,g)
  ##  g.x.each_with_index {|step,i|
  ##    puts [step,i,g.w[i]].join("\t")
  ##  }
  #
  fold_f_g.x.each_with_index {|x_,i|
    puts [x_,fold_f_g.y[i]].join("\t")
  }
  plot(f,"x","y")
end
