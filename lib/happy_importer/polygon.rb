class Polygon

  def initialize
    @points = []
  end

  def points
    @points
  end

  def points=(points)
    @points = points
  end

  def area
    j = @points.length
    n = j
    area = 0
    @points.each_with_index do |p, i|
      j = (i + 1) % n
      area += p.lat * @points[j].long
      area -= @points[j].lat * p.long
    end
    area /= 2.0
  end

  # centroid / center of mass
  def centroid
    cx = 0.0
    cy = 0.0
    j = @points.length
    n = j
    factor = 0.0
    @points.each_with_index() do |p, i|
      j = (i + 1) % n
      factor = p.lat * @points[j].long - @points[j].lat * p.long
      cx += (p.lat + @points[j].lat) * factor
      cy += (p.long + @points[j].long) * factor
    end

    factor = 1 / (area * 6.0)
    cx *= factor
    cy *= factor
    OpenStruct.new(lat: cx, long:cy)
  end

  def radius
    center = centroid
    @points.map{|point| distance(point, center)}.sort.first
  end

  private

  def distance(point1, point2)
    # convert degrees to radians
    point1 = to_radians(point1)
    point2 = to_radians(point2)

    # compute deltas
    dlat = point2.lat - point1.lat
    dlon = point2.long- point1.long

    a = (Math.sin(dlat / 2))**2 + Math.cos(point1.lat) *
      (Math.sin(dlon / 2))**2 * Math.cos(point2.lat)
    c = 2 * Math.atan2( Math.sqrt(a), Math.sqrt(1-a))
    c * 6371000 # Earth Radius in meter
  end

  def to_radians(point)
    OpenStruct.new(lat: point.lat * (Math::PI / 180), long: point.long * (Math::PI / 180))
  end

end
