class Array
  def Array.linspaceByPartition(min,max,partition)
    #$stdout << min
    min, max = min.to_f, max.to_f
    #$stdout << min
    ret = []
    step=(min-max).abs/partition 
    (0..partition).each {|i| ret << min + i * step}
    ret
  end
  def Array.linspaceBySize(min,max,size)
    min, max = min.to_f, max.to_f
    ret = []
    step=(min-max).abs/(size - 1.0)
    (0...size).each {|i| ret << min + i * step}
    ret
  end
end

if __FILE__ == $0
  test_part = Array.linspaceByPartition(-10,10,100)
  require 'pp'
  #pp test_part
  puts "################################################################################"
  test_size = Array.linspaceBySize(-10,10,101)
  require 'pp'
  #pp test_size
  pp (test_size - test_part)
  pp test_part
end
