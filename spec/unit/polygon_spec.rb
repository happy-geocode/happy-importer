# encoding: UTF-8
require 'unit/spec_helper'
require 'ostruct'

describe "polygon should work as accepted" do

  before :all do
    @polygon = Polygon.new
    @polygon.points << OpenStruct.new(lat: 20, long:10)
    @polygon.points << OpenStruct.new(lat: 20, long:20)
    @polygon.points << OpenStruct.new(lat: 10, long:20)
    @polygon.points << OpenStruct.new(lat: 10, long:10)
  end

  it "should create a polygon with points" do
    @polygon.points.length.should eq(4)
  end

  it "should assign points to the polygon" do
    p = Polygon.new
    p.points = [
      OpenStruct.new(lat: 10, long: 10),
      OpenStruct.new(lat: 10, long: 20)
    ]
    p.points.length.should eq(2)
  end

  it "should calculate the area of an polygon" do
    @polygon.area.should eq(100.0)
  end

  it "should calculate the centroid of an polygon" do
    center = @polygon.centroid
    center.lat.round(3).should eq(15.000)
    center.long.round(3).should eq(15.000)
  end

  it "should calculate the minimum radius for a circle around all points in the polygon" do
    @polygon.radius.should eq(776860.1575429044)
  end

  it "should calculate the bounding box" do
    @polygon.bounding_box.should eq([OpenStruct.new(lat:10, long:10), OpenStruct.new(lat:20, long:20)])
  end

  it "should check if point is outside bounding box" do
    @polygon.outside_bounding_box?(OpenStruct.new(lat: 100, long: 100)).should eq(true)
    @polygon.outside_bounding_box?(OpenStruct.new(lat: 14,  long: 14)).should eq(false)
  end

  it "should check if point is inside of polygon" do
    @polygon.contains_point?(OpenStruct.new(lat: 100, long: 100)).should eq(false)
    @polygon.contains_point?(OpenStruct.new(lat: 11, long: 11)).should eq(true)
    @polygon.contains_point?(OpenStruct.new(lat: 10, long: 10)).should eq(true)
  end
end
