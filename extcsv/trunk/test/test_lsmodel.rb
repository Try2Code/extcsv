$:.unshift File.join(File.dirname(__FILE__),"..","lib")
require 'test/unit'
require 'pp'
require 'lsmodel'
require 'matrix'
################################################################################
# Author:: Ralf Müller
################################################################################
class TestLSModel < Test::Unit::TestCase
  def test_lin_reg_linear_model
    x_test = [0,1,2,3,4,5,6,7,8,9]
    y_test = [0,3,5,8,11,14,18,22,10,30]

    s, r   = LSModel.linear_model(x_test,y_test)

    assert_equal(0.762416979330656.to_s, r.to_s)
    assert_equal(2.67719298245614.to_s, s.to_s)
    s_, r_   = LSModel.abstract_model([x_test],y_test,"[ins[0][i]]")
    assert_equal(s,s_[0])
    assert_equal(r,r_)
  end
  def test_lin_reg_compl
    kvs = [80, 80, 100,100, 120,120,140, 140]
    mas = [100,500,100,750,100,750,100,750]
    as  = [ -22.30214352, -26.9980317 , -22.30263873, -25.50091186, -22.30313394, -24.00379202, -22.30362915, -22.50667218]

    s_,r_ = LSModel.abstract_model([kvs,mas],
                                  as,
                                  "[1.0,ins[0][i],ins[1][i],ins[0][i]*ins[1][i]]")
    assert_equal(s_.to_s, "Vector[-20.8775033148882, -0.00979702707072114, -0.020868420605459, 0.000150158141662538]")
    assert_equal(r_.to_s,0.929264062407313.to_s)
  end

  def test_affine_model
    x = [80,100,120]
    y = [0.5267,0.7326,0.6606]
    a , b,  = LSModel.affine_model(x,y)
    assert_equal((a*60.0+b).to_s,0.506066666666667.to_s)

    x = [0,1,2]
    y = x.clone
    a , b, = LSModel.affine_model(x,y)
    s, = LSModel.linear_model(x,y)
    assert_equal(1.0,a)
    assert_equal(s,a)

    y.each_index {|i| y[i] = y[i]*5.5}
    a , b, = LSModel.affine_model(x,y)
    s, = LSModel.linear_model(x,y)
    assert_equal(5.5,a)
    assert_equal(s,a)

    y.each_index {|i| y[i] = y[i] + 3.3}
    a , b, r = LSModel.affine_model(x,y)
    assert_equal(1.0,r)
    s,r = LSModel.linear_model(x,y)
    assert_equal(0.784,r)
    assert_not_equal(a,s)
    assert_equal(5.5.to_s,a.to_s)
    assert_equal(3.3.to_s,b.to_s)
  end

  def test_modelHasConst
    model = LSModel.convertModelInputString("input[1],input[0]*input[0]")
    assert_equal(false, LSModel.modelHasConstant?(model))
    model = LSModel.convertModelInputString("1.0,input[0],input[1],input[0]*input[1]")
    assert_equal(true, LSModel.modelHasConstant?(model))
    model = LSModel.convertModelInputString("input[0],input[1],input[0]*input[1],1.0")
    assert_equal(true, LSModel.modelHasConstant?(model))
    model = LSModel.convertModelInputString("input[0],input[1],1.0,input[0]*input[1]")
    assert_equal(true, LSModel.modelHasConstant?(model))
  end
  def test_modelDim
    model = LSModel.convertModelInputString("input[1],input[0]*input[0]")
    assert_equal(2, LSModel.modelDim(model))
    model = LSModel.convertModelInputString("1.0,input[0],input[1],input[0]*input[1]")
    assert_equal(4, LSModel.modelDim(model))
    assert_equal(3, LSModel.modelDim(model,true))
    model = LSModel.convertModelInputString("input[1],1.0,input[0]*input[1]")
    assert_equal(3, LSModel.modelDim(model))
    assert_equal(2, LSModel.modelDim(model,true))
    model = LSModel.convertModelInputString("input[1],input[0]*input[1],Math.sqrt(input[3])")
    assert_equal(3, LSModel.modelDim(model))
    assert_equal(3, LSModel.modelDim(model,true))
  end

  def test_abstract_modelD
    kvs = [80, 80, 100,100, 120,120,140, 140]
    mas = [100,500,100,750,100,750,100,750]
    outs = []
    (0..7).each {|i| outs << [kvs[i]*mas[i]*Math.sqrt(kvs[i]*mas[i]), kvs[i]+mas[i]]}
    input  = Matrix.columns([kvs,mas])
    output = Matrix.columns(outs.transpose)
#    pp input.column_vectors
    model = "input[1],input[0]*input[0]"
#    model_ = "[" + model.gsub(/\[(\d+)\]/,"\[i,\\1\]") + "]"
#    pp outs.transpose
    LSModel.abstract_modelD([kvs,mas], outs.transpose, model)
  end
  def test_modelOutput
    #TODO: unterschiede zum alten modell immernoch vorhanden!!! weiss nicht, warum
    kvs = ["80", 80, 100,100, 120,120,140, "140"]
    mas = [100,"500",100,750,100,750,100,750]
    as  = [ -22.30214352, -26.9980317 , -22.30263873, -25.50091186, -22.30313394, -24.00379202, -22.30362915, -22.50667218]
    model = "1.0,input[0],input[1],input[0]*input[1]"
    s_, r_ = LSModel.abstract_modelD([kvs,mas],
                                 [as],
                                 model)
    modelOutput = LSModel.modelOutput(model, s_, [[80,100],[80,500],[100,"100"]])
    #pp as
    #puts '##############################'
    #pp modelOutput
    #puts '##############################'
    s, r = LSModel.abstract_model([kvs,mas],
                                 as,
                                 "[1.0,ins[0][i],ins[1][i],ins[0][i]*ins[1][i]]")
    assert_equal(s.inspect,s_.column(0).inspect)
    test = LSModel.test_model([[80,80,100],[100,500,100]],
                         as[0,3],
                         "[1.0,ins[0][i],ins[1][i],ins[0][i]*ins[1][i]]",
                         s)
    #pp test
    #puts '##############################'
    assert_equal(modelOutput.column(0).to_a, test[:model])
  end
  def test_abstract_model
    kvs = ["80", 80, 100,100, 120,120,140, "140"]
    mas = [100,"500",100,750,100,750,100,750]
    as  = [ -22.30214352, "-26.9980317" , -22.30263873, -25.50091186, -22.30313394, -24.00379202, -22.30362915, -22.50667218]

    s, r = LSModel.abstract_model([kvs,mas],
                                 as,
                                 "[1.0,ins[0][i],ins[1][i],ins[0][i]*ins[1][i]]")
    s_, r_ = LSModel.abstract_modelD([kvs,mas],
                                 [as],
                                 "1.0,input[0],input[1],input[0]*input[1]")
    #pp s
    #pp r
    #pp s_.column_vectors
    #pp r_
    assert_equal(Matrix[[0.0],[0.0],[0.0],[0.0]],s-s_)
    assert_equal(Vector[-20.8775033148882, -0.00979702707072114, -0.020868420605459, 0.000150158141662538].to_a.flatten.to_s,s.to_a.flatten.to_s)
    assert_equal(0.929264.to_s, r.to_s[0,8])
    test = LSModel.test_model([kvs,mas],
                         as,
                         "[1.0,ins[0][i],ins[1][i],ins[0][i]*ins[1][i]]",
                         s)
    assert_equal(0.929264.to_s,test[:r].to_s[0,8])
  end
end
