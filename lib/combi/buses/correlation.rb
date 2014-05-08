module Combi
  class Correlation
    def self.generate
      "#{Thread.current.object_id}_#{rand(10_000_000)}"
    end
  end
end
