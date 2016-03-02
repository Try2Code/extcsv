$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'convolution'
require 'pp'
require 'rubygems'
#require 'tube_data'
#require 'tube_data_display'
include CPlot
include Convolution


class TestConv < Test::Unit::TestCase
  MAINDIR = "/cygdrive/d/src/temple2depth/"
  TESTDATADIR = MAINDIR + "test/data"
  TESTDATAFILE = "Tempel3_0A.txt"

  def instantLinKernel
    ConvolutionKernel.new("lin",2,4)
  end
  def myinstantLinKernel(width)
    ConvolutionKernel.new("lin",width.to_f,2*width)
  end
  def instantUnitKernel
    ConvolutionKernel.new("exp",0.2,100)
  end
  def myinstantUnitKernel(width)
    ConvolutionKernel.new("exp",width.to_f,100)
  end
  def mydiscreteinstantUnitKernel(width, magnification=2)
    ConvolutionKernel.new("exp",width,magnification*width)
  end
  def instantProfile
    f         = OpenStruct.new
    f.x , f.y = GSL::Vector.filescan(TESTDATADIR+"/"+TESTDATAFILE)
    f
  end
  def ProfileByFile(file)
    f         = OpenStruct.new
    f.x , f.y = GSL::Vector.filescan(file)
    f
  end
  def test_linkernels
   lka = instantLinKernel
   lkb = myinstantLinKernel(2)
   assert_equal(lka,lkb)
  end
  def test_integral
    lk = instantLinKernel 
    uk = instantUnitKernel
    assert_equal(1.0.to_s,lk.integral.to_s)
    assert_equal(1.0.to_s,uk.integral.to_s)
    [0.1, 0.2, 0.4, 0.5, 0.7, 0.8].each {|wd|
      assert_equal(1.0.to_s,myinstantUnitKernel(wd).integral.to_s)
    }
    [1,2,3,4,5,6,7,8,10,12,20,50].each {|wd|
      assert_equal(1.0.to_s,myinstantLinKernel(wd).integral.to_s)
      assert_equal(1.0.to_s,mydiscreteinstantUnitKernel(wd,4).integral.to_s)
    }
  end
# def test_conv
#   width = 2
#   lk    = instantLinKernel
#   uk    = mydiscreteinstantUnitKernel(width)
#   width = 5
#   lk    = myinstantLinKernel(width)
#   uk    = mydiscreteinstantUnitKernel(width)
#   x,int = GSL::Vector.filescan(TESTDATADIR+"/"+TESTDATAFILE)
#   f     = OpenStruct.new
#   f.y   = int
#   f.x   = x
#   clk   = Convolution.conv(f,lk)
#   cuk   = Convolution.conv(f,uk)
#   [f,clk,cuk].each {|ff| $stdout << ff.y.class << "\n"}
#
#  td = TubeData.new("hash","plain",{
#    :x => f.x.to_a, 
#    :y => f.y.to_a,
#    :clk => clk.y.to_a,
#    :cuk => cuk.y.to_a,
#    :diff_y_l => ((f.y - clk.y)/f.y.max).to_a,
#    :diff_y_u => ((f.y - cuk.y)/f.y.max).to_a,
#    :diff_l_u => (clk.y - cuk.y).to_a
#  })
#
#  TubeDiagram.plot(td,
#                   [],
#                   :x,
#                   [
#                  :y,
#                  :clk,
#                   :cuk,
#                    :diff_y_l,
#                    :diff_y_u,
#                     :diff_l_u
#                   ],
#                   '','','',
#                   :type => "lines",
#                   :linewidth => 1,
#                   :xrange => '[80:130]',
#                   :xrange => '[:]',
#                   :yrange => '[:]')
# end

  def test_bench
    f         = OpenStruct.new
    f.x , f.y = GSL::Vector.filescan(TESTDATADIR+"/"+TESTDATAFILE)
    widths    = [5,10,50,100,200]         
    puts "Old Version"
    times = {}
    widths.each {|width|
      t0  = Time.new
      #lk    = myinstantLinKernel(width)
      uk    = mydiscreteinstantUnitKernel(width)
      #clk = Convolution.conv(f,lk)
      cuk = Convolution.conv(f,uk)
      dt  = Time.new - t0
      times[width] = dt
    } if false
    times.each {|t,dt| puts [t,dt].join("\t")}
    puts "New Version"
    times = {}
    widths.each {|width|
      t0  = Time.new
      lk    = myinstantLinKernel(width)
      uk    = mydiscreteinstantUnitKernel(width)
      clk = Convolution.convolute(f,lk)
      cuk = Convolution.convolute(f,uk)
      #GSL::graph(cuk.x,cuk.y)
      dt  = Time.new - t0
      times[width] = dt
    }
    times.each {|t,dt| puts [t,dt].join("\t")}
  end

  def test_expand
    xVec = GSL::Vector.alloc([0,1,2,3,4,5,6,7,8,9])
    width = 2
    exp = expand(xVec,width)
   # pp exp
    assert_equal(14,exp.size)
    assert_equal(GSL::Vector.connect(GSL::Vector.alloc([2,1]),xVec,GSL::Vector.alloc([8,7])), exp)
  end

  def test_newconv
    xVec   = GSL::Vector.alloc([0,1,2,3,4,5,6,7,8,9])
    yVec   = xVec.collect {|x| x**2+rand(10)}
    f      = OpenStruct.new
    f.x    = xVec; f.y = yVec
    width  = 2
    uk     = mydiscreteinstantUnitKernel(width)
    cukNew = Convolution.convolute(f,uk)
    cuk    = Convolution.conv(f,uk)
    assert_equal(10,cukNew.y.size)
    #GSL::graph(cukNew.x,cukNew.y,f.y)
    assert_equal(cuk.y[1..-2],cukNew.y[1..-2])
  end

  def test_interp
    f         = OpenStruct.new
    f.x , f.y = GSL::Vector.filescan(TESTDATADIR+"/"+TESTDATAFILE)
    width = 5
    n     = f.y.size
    lk    = myinstantLinKernel(width)
    uk    = mydiscreteinstantUnitKernel(width)
    clk   = Convolution.conv(f,lk)
    cuk   = Convolution.conv(f,uk)
    interp_f =GSL::Spline.alloc("akima", n)
    interp_f.init(f.x, f.y)
    interp_l =GSL::Spline.alloc("akima", n)
    interp_l.init(f.x, clk.y)
    interp_u = GSL::Spline.alloc("akima", n)
    interp_u.init(f.x, cuk.y)
    datakeys = [:y,:clk,:cuk]
    datasets = {:y=>[],:clk=>[],:cuk=>[]}
      x_enl = GSL::Vector.linspace(f.x.min, f.x.max, f.x.size*2)
    [interp_f, interp_l, interp_u].each_with_index {|interp,i|
      ydata = [f.y,clk.y,cuk.y][i]
#      x_enl = GSL::Vector.linspace(f.x.min, f.x.max, f.x.size*1)
#      x_enl = f.x
      x_enl.each {|x_| datasets[datakeys[i]] << interp.eval(x_)}
    }
#  td = TubeData.new("hash","plain",{
#    :x => x_enl.to_a,#f.x.to_a, 
#    :y => datasets[:y].to_a,
#    :clk => datasets[:clk].to_a,
#    :cuk => datasets[:cuk].to_a#,
#     :diff_y_l => ((f.y - clk.y)/f.y.max).to_a,
#     :diff_y_u => ((f.y - cuk.y)/f.y.max).to_a,
#     :diff_l_u => (clk.y - cuk.y).to_a
#  })
#  TubeDiagram.plot(td,
#                   [],
#                   :x,
#                   [
#                  :y,
#                  :clk,
#                   :cuk#,
#                     :diff_y_l,
#                     :diff_y_u,
#                      :diff_l_u
#                   ],
#                   '','','',
#                   :type => "lines",
#                   :linewidth => 1,
#                   :xrange => '[50:150]',
#                    :xrange => '[:]',
#                   :yrange => '[:]')
  end

  def test_compute_depth(file, plot=true, mode=:min)
    f = ProfileByFile(file)
    # convolution
    k    = mydiscreteinstantUnitKernel(5)
    ck   = Convolution.conv(f,k)
    # split profile
    size = ck.x.size.to_f
    middlesize = (size/100 * 10).floor
    xl = ck.x[0...(size/2-middlesize)]
    yl = ck.y[0...(size/2-middlesize)]
    xr = ck.x[size/2+middlesize...size]
    yr = ck.y[size/2+middlesize...size]
    #
    ## leave out first and last 5% of the measurements
    borderwidth = (size/100 * 3).floor
    size = xl.size
    # left
    xl = xl[borderwidth...(size-borderwidth)]
    yl = yl[borderwidth...(size-borderwidth)]
    # right
    xr = xr[0...(size-borderwidth)]
    yr = yr[0...(size-borderwidth)]

  # if plot 
  #   td = TubeData.new("hash","plain",{
  #     :x => ck.x.to_a,
  #     :y => ck.y.to_a
  #   })
  #   td.gnuplot('x',['y'],:mode => 'free',:graph_title => file)
  #   td = TubeData.new("hash","plain",{
  #     :xl => xl.to_a,
  #     :yl => yl.to_a
  #   })
  #   td.gnuplot('xl',['yl'],:mode => 'free',:xrange => "[#{xl[0]}:#{xl[-1]}]",:graph_title => file)
  #   td = TubeData.new("hash","plain",{
  #     :xr => xr.to_a,
  #     :yr => yr.to_a
  #   })
  #   td.gnuplot('xr',['yr'],:mode => 'free',:xrange => "[#{xr[0]}:#{xr[-1]}]",:graph_title => file)
  # end

    # find extremum
    minl =  xl[yl.max_index]
    minr =  xr[yr.max_index]
    print "max - links: #{minl}\n"
    print "max - rechts: #{minr}\n"
    print "Pixelabstand der Extrema: " + (minr-minl).to_s + " "
    diff = (minl - minr).abs
    x_diff = diff*0.169319336268202 # made for 150dpi: number of Millimeters per pixel
 
    #puts x_diff
    depth = 24*138.8/(x_diff - 24.0) - 10.1
    printf "%.20f ", depth, " "
  end
  def test_multi_depth
    files = ["/cygdrive/f/src/temple2depth/images/CT203_STM/T_0_profile.txt",
             "/cygdrive/f/src/temple2depth/images/CT203_STM/T_0_0deg_profile.txt", 
             "/cygdrive/f/src/temple2depth/images/CT203_STM/T_0_1deg_profile.txt", 
             "/cygdrive/f/src/temple2depth/images/CT203_STM/T_minus1_profile.txt", 
             "/cygdrive/f/src/temple2depth/images/CT203_STM/T_minus2_profile.txt", 
             "/cygdrive/f/src/temple2depth/images/CT203_STM/T_minus3_profile.txt"]
      plot = false
    files[0,3].each_with_index {|file,i|
      puts "############################################################"
      puts [File.basename(file),test_compute_depth(file,plot)].join("\t")
    }
    Dir.glob("/cygdrive/f/src/temple2depth/images/CT203_STM/x_width/t*profile*.txt").each_with_index {|file,i|
      puts "############################################################"
      puts [File.basename(file),test_compute_depth(file,plot)].join("\t")
      #plot = (i==2) ? true : false
    }
    Dir.glob("/cygdrive/f/src/temple2depth/images/CT203_STM/x_width/crop*Profile*.txt").each_with_index {|file,i|
      puts "############################################################"
      puts [File.basename(file),test_compute_depth(file,plot)].join("\t")
      #plot = (i==2) ? true : false
    }
    puts "##### X  ==  LENGTH   ######################################"
    Dir.glob("/cygdrive/f/src/temple2depth/images/CT203_STM/x_length/t*.txt").each_with_index {|file,i|
      puts "############################################################"
      puts [File.basename(file),test_compute_depth(file,plot)].join("\t")
      #plot = (i==2) ? true : false
    }
  end

  def test_fd071
    file = "/cygdrive/f/src/temple2depth/images/FDTubes/crop_FD071_width_Profile.txt"
      puts [File.basename(file),test_compute_depth(file,true)].join("\t")
    file = "/cygdrive/f/src/temple2depth/images/FDTubes/crop_FD071_width_Profile_iJ.txt"
      puts [File.basename(file),test_compute_depth(file,true)].join("\t")
    file = "/cygdrive/f/src/temple2depth/images/FDTubes/crop_FD071_width_Profile_iJ_.txt"
      puts [File.basename(file),test_compute_depth(file,true)].join("\t")
  end
  def test_4stefan
    file = "/cygdrive/f/src/temple2depth/images/4stefan_gerlach_crop_width_Profile.txt"
      puts [File.basename(file),test_compute_depth(file,true)].join("\t")
  end


  def test_get_minmax
    f = instantProfile
    # convolution
    k    = mydiscreteinstantUnitKernel(5)
    ck   = Convolution.conv(f,k)
    #
    # split profile
    size = ck.x.size.to_f
    puts size
    ## leave out the 20% in the middle of the temple, in this area the profiles
    ## is influenced ny the central spot of the temple
    middlesize = (size/100 * 10).floor
    puts middlesize
    puts (size/2-middlesize)
    puts (size/2+middlesize)
    puts "################################################################################"
    puts ck.x.size
    puts ck.y.size
    puts ck.x.class
    puts ck.y.class
    puts "################################################################################"
    xl = ck.x[0...(size/2-middlesize)]
    yl = ck.y[0...(size/2-middlesize)]
    xr = ck.x[size/2+middlesize...size]
    yr = ck.y[size/2+middlesize...size]
    #
    ## leave out first and last 5% of the measurements
    borderwidth = (size/100 * 5).floor
    size = xl.size
    puts borderwidth
    puts size-borderwidth
    puts "################################################################################"
    puts xl.size
    puts yl.size
    puts "################################################################################"
    # left
    xl = xl[borderwidth...(size-borderwidth)]
    yl = yl[borderwidth...(size-borderwidth)]
    # right
    xr = xr[0...(size-borderwidth)]
    yr = yr[0...(size-borderwidth)]

   # td = TubeData.new("hash","plain",{
   #   :xl => xl.to_a,
   #   :yl => yl.to_a
   # })
   # td.gnuplot('xl',['yl'],:mode => 'free',:xrange => '[90:115]')
   # td = TubeData.new("hash","plain",{
   #   :xr => xr.to_a,
   #   :yr => yr.to_a
   # })
   # td.gnuplot('xr',['yr'],:mode => 'free',:xrange => '[470:485]')

    # find extremum
   minl =  xl[yl.min_index]
   minr =  xr[yr.min_index]
   puts  xl[yl.min_index]
   puts  xr[yr.min_index]
   diff = (minl - minr).abs
   x_diff = diff*0.169319336268202
   puts x_diff
   depth = 24*138.8/(x_diff - 24.0) - 10.1
   puts depth
   printf "%.20f", depth
   assert_equal(76.8548971077009.to_s,depth.to_s)
  end

end

