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
    # This method raises ZeroDivisionError if number is 0.
    Rational(1, number)
  end

  def self.sort_as_integer(str_numbers)
    # This should be str_numbers.sort_by(&:to_i) but it doesn't.
    str_numbers.sort
  end
end
