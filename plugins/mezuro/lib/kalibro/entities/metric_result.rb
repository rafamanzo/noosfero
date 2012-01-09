class Kalibro::Entities::MetricResult < Kalibro::Entities::Entity

  attr_accessor :metric, :value, :range, :descendent_result

  def metric=(value)
    if value.kind_of?(Hash)
      @metric = to_entity(value, Kalibro::Entities::CompoundMetric) if value.has_key?(:script)
      @metric = to_entity(value, Kalibro::Entities::NativeMetric)
    else
      @metric = value
    end
  end

  def range=(value)
    @range = to_entity(value, Kalibro::Entities::Range)
  end

  def descendent_result=(value)
    @descendent_result = to_entity_array(value)
  end

  def descendent_results
    @descendent_result
  end

  def descendent_results=(descendent_results)
    @descendent_result = descendent_results
  end

end