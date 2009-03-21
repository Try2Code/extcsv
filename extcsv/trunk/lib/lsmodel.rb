require 'matrix'
require 'mathn'

# Modelling funtionality with the least square mathod
module LSModel
  MINIMAL_VARIATION_SIZE = 8

  # Function for simple computation of the slope of y over x, i.e. y =
  # ax, x is input and y is the measured value. Both should behave
  # like arrays. 
  # This is the direct version of what the abstract modelling method would do
  def LSModel.linear_model(x,y)
    return nil if x.size != y.size

    # recursive to_f for x and y
    params = [x, y]
    params.each_with_index {|param,index|
      params[index] = param.each_with_index {|v,i| param[i] = v.to_f}
    }

    s   = nil
    x_V = Vector.elements(x)
    y_V = Vector.elements(y)
    s   = x_V.inner_product(y_V)/x_V.inner_product(x_V)
   
    r,  = stability_index("linear",s,y,x)

    [s, r]
  end

  # Method for affine regression y = ax + b 
  # This is the direct version of what the abstract modelling method would do
  def LSModel.affine_model(x,y)
    return nil if x.size != y.size
    n = x.size.to_f
    params = [x, y]
    params.each_with_index {|param,index|
      params[index] = param.each_with_index {|v,i| param[i] = v.to_f}
    }
    x_V = Vector.elements(x)
    y_V = Vector.elements(y)
    x_S = x.inject {|sum,x_i| sum += x_i}
    y_S = y.inject {|sum,y_i| sum += y_i}
    # gradient
    a = (n*x_V.inner_product(y_V) - x_S*y_S)/(n*x_V.inner_product(x_V) - x_S*x_S)
    # offset
    b = (y_S - a*x_S)/n
    # fitnes
    r,  = stability_index("affine",[a,b],y,x)
    [a,b,r]
  end


  # mode abstract Modelling: multiple (but same) dimesions are allowed in
  # input/output data arrays (ins, out)
  # model should have the form:
  # <tt>"[1.0,input[0][i],input[1][i]]"</tt> for affine model
  #
  # !!EXPERIMENTAL!! Better use abstract_model
  def LSModel.abstract_modelD(ins, outs, model)
    ###########################################################################
    # Calculation of the coefficients for the given model
    #
    # check for data quality
    # 1. Is there enough data?
    if ins[0].size < 2
      puts "To few datasets!"
      raise
    end
    # 2. Has any dataset the same size?
    sizes = []
    [ins,outs].each {|datas| datas.each {|dataset| sizes << dataset.size}}
    if sizes.uniq.size != 1
      puts "Use datasets with same number of values!"
      raise
    end
    # 3. Convert everything from String to Float
    [ins,outs].each {|datas| datas.collect!{|data| data.collect {|data_| data_.to_f}}}
    # 4. preprocess the model
    model = convertModelInputString(model)
    # Create input/output matrices
    input  = Matrix.columns(ins)
    output = Matrix.columns(outs)

    # Create the modelling Matrix
    rows = []
    (0...sizes[0]).each {|i| rows << eval(model) }
    model_matrix = Matrix.rows(rows)

    # Computation of coefficients
    model_coeffs = (model_matrix.transpose * model_matrix).inverse * model_matrix.transpose * output
    
    ###########################################################################
    # Calculation of the stability
    r_total  = 0.0
    r_reg    = 0.0
    r_res    = 0.0
    modelDim = modelDim(model,true)
    #test p model + "=>" + "modelDim: " + modelDim.to_s
    # mean values for each measured variable
    n = output.row_size
    meanValues = []
    output.column_vectors.each {|cv| meanValues << cv.to_a.inject {|sum,v| sum + v}/n}
    # each measurement variable has to be treated separately
    stability = []
    output.column_vectors.each_with_index {|output_vector,k|
      modelOutput = model_matrix * model_coeffs.column(k)
      output_vector.to_a.each_with_index {|output_value,i|
        r_total += (output_value   - meanValues[k])**2
        r_res   += (output_value   - modelOutput[i])**2
        r_reg   += (modelOutput[i] - meanValues[k])**2
      }
      r = r_reg/r_total
      r_improved = 1.0 - (1.0 - r**2)*(k-1.0)/(k - modelDim -1.0)
      stability << [r,r_improved]
    }

    return [model_coeffs, stability]
  end

  def LSModel.convertModelInputString(model)
    "[" + model.gsub(/\[(\d+)\]/,"\[i,\\1\]") + "]"
  end

  def LSModel.modelHasConstant?(model)
    input      = Matrix.scalar(100,0.0)
    i          = 0
    modelArray = eval(model)
    modelArray.include?(1.0)
  end

  # For the calculation of the adjusted stability index, a special Dimensionis
  # needed: the number of coefficients without the constant term.
  def LSModel.modelDim(model,forAdjustedStability=false)
    input      = Matrix.scalar(100,0.0)
    i          = 0
    dim = eval(model).size
    (forAdjustedStability and modelHasConstant?(model)) ? dim - 1 : dim
  end

  def LSModel.modelOutput(model, model_coeffs, inputs)
    inputs.collect!{|input| input.collect {|inn| inn.to_f}}
    input = Matrix.rows(inputs)
    model = convertModelInputString(model)
    # Create the modelling Matrix
    rows  = []
    (0...input.row_size).each {|i| rows << eval(model) }
    model_matrix = Matrix.rows(rows)
    #test pp model_matrix
    modelOutput = model_matrix * model_coeffs
  end

  # Abstract modelling method. See test files for usage.
  def LSModel.abstract_model(ins, outs, model, force=false)
    minimal_variaion_size = (force) ? 2 : MINIMAL_VARIATION_SIZE
    unless (ins[0].size == outs.size and outs.size >= minimal_variaion_size)
      $stdout << "ERROR:\nMINIMAL_VARIATION_SIZE #{MINIMAL_VARIATION_SIZE} is not reached!\n"
      $stdout << "Only #{ins[0].size} measurements are present.\n"
      raise
    end

    params = [outs,ins]
    params.each_with_index {|param,index|
      if index == 0 
        # 'out' is a single array 
        params[index] = param.each_with_index {|v,i| param[i] = v.to_f}
      else 
        # 'ins' is an array of arrays
        param.each_with_index {|inn,i|
          param[i] = inn.each_with_index {|v,i| inn[i] = v.to_f}
        }
        params[index] = param
      end
    }
    out_vector = Vector.elements(outs)
    rows       = []
    (0..ins.first.size-1).each {|i|
      rows << eval(model)
      var = eval(model)
    }
    matrix       = Matrix.rows(rows)
    model_coeffs = (matrix.transpose * matrix).inverse * matrix.transpose * out_vector
    r,           = abstract_stability_index(ins,
                                            outs,
                                            model,
                                            model_coeffs)
    [model_coeffs,r]
  end

  # Computation of fjhgugui<F5>zt56789gfrihi
  #
  # ,löl,00, <- this was nick ;)
  #
  # Computation of stability index according the the given model with its
  # coeffs
  def LSModel.abstract_stability_index(ins,outs,model,model_coeffs)
    r_total  = 0.0
    r_reg    = 0.0
    r_res    = 0.0
    n        = outs.size.to_f
    outs_mid = outs.inject {|sum,i| sum + i } / n

    outs.each_with_index {|out,i|
      out_by_model = model_coeffs.inner_product(Vector.elements(eval(model)))
      r_total += (outs[i] - outs_mid)      * (outs[i] - outs_mid)   
      r_res   += (outs[i] - out_by_model)  * (outs[i] - out_by_model)  
      r_reg   += (out_by_model - outs_mid) * (out_by_model - outs_mid)
    }

    r_ = r_reg/r_total
    r  = 1.0 - r_res/r_total

    [r, r_]
  end

  # This function computed the know variance according the the model given by
  # the 'mode' parameter:
  # * 'linear' for the linear model y=s*x
  def LSModel.stability_index(mode, s, y, *x)
    r_total = 0.0
    r_reg   = 0.0
    r_res   = 0.0
    n       = y.size.to_f
    y_mid   = y.inject {|sum,i| sum + i } / n

    case mode
    when "linear"
      x = x[0]
      y.each_with_index {|y_i,i|
        ys_i     = s*x[i]
        r_total += (y_i - y_mid)  * (y_i - y_mid)   
        r_res   += (y_i - ys_i)   * (y_i - ys_i)  
        r_reg   += (ys_i - y_mid) * (ys_i - y_mid)
      }
    when "affine"
      a, b = s
      y.each_with_index {|y_i,i|
        ys_i     = a*x[0][i] + b
        r_total += (y_i - y_mid)  * (y_i - y_mid)   
        r_res   += (y_i - ys_i)   * (y_i - ys_i)  
        r_reg   += (ys_i - y_mid) * (ys_i - y_mid)
      }
    else
      puts "Wrong working mode in function 'stability_index'! " +
           "Use 'linear' or 'affine' instead.'"
      raise
    end

    r_ = r_reg/r_total
    r  = 1.0 - r_res/r_total

    [r, r_]
  end
  def LSModel.test_model(ins, out, model, model_coeffs)
    params = [out,ins]
    params.each_with_index {|param,index|
      if index == 0 # 'out' is a single array 
        params[index] = param.each_with_index {|v,i| param[i] = v.to_f}
      else # 'ins' is an array of arrays
        param.each_with_index {|inn,i|
          param[i] = inn.each_with_index {|v,i| inn[i] = v.to_f}
        }
        params[index] = param
      end
    }
    r_total  = 0.0
    r_reg    = 0.0
    r_res    = 0.0
    n        = out.size.to_f
    out_mid  = out.inject {|sum,i| sum + i } / n

    model_out  = []
    model_diff = []

    out.each_with_index {|value,i|
      out_by_model = model_coeffs.inner_product(Vector.elements(eval(model)))
      model_out  << out_by_model
      model_diff << out_by_model - value
      r_total += (value - out_mid)       * (value - out_mid)   
      r_res   += (value - out_by_model)  * (value - out_by_model)  
      r_reg   += (out_by_model - out_mid) * (out_by_model - out_mid)
    }

    r_ = r_reg/r_total
    r  = 1.0 - r_res/r_total

    {:r => r,:model => model_out, :diff => model_diff}
  end
end
