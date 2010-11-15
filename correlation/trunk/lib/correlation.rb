require "gsl"

# This Extension of the GNU Scientific Library bindings by Yoshiki Tsunesada
# (http://rb-gsl.rubyforge.org) provides the computation of the correlation of two
# GSL::Vectors. It is implemented as a method of a GSL::Vector for most easy
# usage. see project page: http://rubyforge.org/projects/extcsv
class GSL::Vector

  # Follow the usual definition, e.g. from Sheriff and Geldart "Exploitation
  # Seismology", p. 289: cor(v,w)(i) = sum_over_k (v[k]*w[k+i])
  #
  # This means, that
  # * for positive values of i, w is shifted to the left, i.e. in the direction of smaller indizees of v
  # * for negative i, w is shifted to the right, i.e. in the direction of larger indizees of v
  def correlation(other)
    unless size == other.size
      warn "Vectors/Datasets must have the same size."
      raise
    end

    # predefine result vector
    correlation = GSL::Vector.alloc(2*size+1)

    # Alternate definition, which is actually the opposite direction of the definition
    # (0...size).each {|i|
    #   correlation << self[0..i]*other[-i-1..-1].col
    # }
    # (1...size).each {|i|
    #   correlation << self[i..size-1]*other[0...size-i].col
    # }
    (0...size).each {|i|
      correlation[0] = (self.to_a[-i-1..-1].to_gv)*(other.to_a[0..i].to_gv.col)
    }
    (1...size).each {|i|
      correlation[size+i] = (self.to_a[0...size-i].to_gv)*(other.to_a[i..size-1].to_gv.col)
    }

    [GSL::Vector.linspace(-size+1, size-1, 2*size-1) , correlation]
  end
  def autocorrelation
    correlation(self)
  end
end
