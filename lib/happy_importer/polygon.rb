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
    upoints = unique_points
    j = upoints.length
    n = j
    area = 0
    upoints.each_with_index do |p, i|
      j = (i + 1) % n
      area += p.lat * upoints[j].lon
      area -= upoints[j].lat * p.lon
    end
    area /= 2.0
  end

  # centroid / center of mass
  def centroid
    upoints = unique_points
    if upoints.length <= 2
      return @points.first
    end

    cx = 0.0
    cy = 0.0
    j = upoints.length
    n = j
    factor = 0.0
    upoints.each_with_index() do |p, i|
      j = (i + 1) % n
      factor = p.lat * upoints[j].lon - upoints[j].lat * p.lon
      cx += (p.lat + upoints[j].lat) * factor
      cy += (p.lon + upoints[j].lon) * factor
    end

    factor = 1 / (area * 6.0)
    cx *= factor
    cy *= factor
    OpenStruct.new(lat: cx, lon:cy)
  end

  def radius
    uniqpoints = unique_points
    if uniqpoints.length <= 2
      return 500
    end
    center = centroid
    uniqpoints.map{|point| distance(point, center)}.sort.last
  end

  def unique_points
    @points.uniq{|p| "#{p.lat}-#{p.lon}"}
  end

  # This Code can be found here:
  # http://jakescruggs.blogspot.de/2009/07/point-inside-polygon-in-ruby.html
  def contains_point?(point)
    return false if outside_bounding_box?(point)
    contains_point = false
    i = -1
    j = @points.size - 1
    while (i += 1) < @points.size
      a_point_on_polygon = @points[i]
      trailing_point_on_polygon = @points[j]
      if point_is_between_the_lons_of_the_line_segment?(point, a_point_on_polygon, trailing_point_on_polygon)
        if ray_crosses_through_line_segment?(point, a_point_on_polygon, trailing_point_on_polygon)
          contains_point = !contains_point
        end
      end
      j = i
    end
    return contains_point
  end

  def outside_bounding_box?(point)
    min, max = bounding_box
    point.lat < min.lat || point.lat > max.lat || point.lon < min.lon || point.lon > max.lon
  end

  def bounding_box
    upper_left  = OpenStruct.new(lat: nil, lon: nil)
    lower_right = OpenStruct.new(lat: nil, lon: nil)
    @points.each do |point|
      upper_left.lat  = point.lat  if upper_left.lat   == nil || upper_left.lat   > point.lat
      upper_left.lon = point.lon if upper_left.lon  == nil || upper_left.lon  > point.lon
      lower_right.lat = point.lat  if lower_right.lat  == nil || lower_right.lat  < point.lat
      lower_right.lon= point.lon if lower_right.lon == nil || lower_right.lon < point.lon
    end
    [upper_left, lower_right]
  end

  private

  def point_is_between_the_lons_of_the_line_segment?(point, a_point_on_polygon, trailing_point_on_polygon)
    (a_point_on_polygon.lon <= point.lon && point.lon < trailing_point_on_polygon.lon) ||
      (trailing_point_on_polygon.lon <= point.lon && point.lon < a_point_on_polygon.lon)
  end

  def ray_crosses_through_line_segment?(point, a_point_on_polygon, trailing_point_on_polygon)
    (point.lat < (trailing_point_on_polygon.lat - a_point_on_polygon.lat) * (point.lon - a_point_on_polygon.lon) /
     (trailing_point_on_polygon.lon - a_point_on_polygon.lon) + a_point_on_polygon.lat)
  end

  def distance(point1, point2)
    # convert degrees to radians
    point1 = to_radians(point1)
    point2 = to_radians(point2)

    # compute deltas
    dlat = point2.lat - point1.lat
    dlon = point2.lon- point1.lon

    a = (Math.sin(dlat / 2))**2 + Math.cos(point1.lat) *
      (Math.sin(dlon / 2))**2 * Math.cos(point2.lat)
    c = 2 * Math.atan2( Math.sqrt(a), Math.sqrt(1-a))
    c * 6371000 # Earth Radius in meter
  end

  def to_radians(point)
    OpenStruct.new(lat: point.lat * (Math::PI / 180), lon: point.lon * (Math::PI / 180))
  end

end
