# frozen_string_literal: true

module PbtTest
  def self.biggest(arr, max = nil)
    return max if arr.empty?
    head, *tail = arr
    if !max || head >= max
      biggest(tail, head)
    else
      biggest(tail, max)
    end
  end
end
