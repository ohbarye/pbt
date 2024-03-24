# frozen_string_literal: true

module PbtTestTarget
  def self.biggest(arr, max = nil)
    return max if arr.empty?
    head, *tail = arr
    if !max || head >= max
      biggest(tail, head)
    else
      biggest(tail, max)
    end
  end

  def self.reciprocal(number)
    Rational(1, number)
  end
end
