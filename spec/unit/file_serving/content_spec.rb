#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_serving/content'

describe Puppet::FileServing::Content do
  let(:path) { File.expand_path('/path') }

  it "should be a subclass of Base" do
    expect(Puppet::FileServing::Content.superclass).to equal(Puppet::FileServing::Base)
  end

  it "should indirect file_content" do
    expect(Puppet::FileServing::Content.indirection.name).to eq(:file_content)
  end

  it "should only support the raw format" do
    expect(Puppet::FileServing::Content.supported_formats).to eq([:raw])
  end

  it "should have a method for collecting its attributes" do
    expect(Puppet::FileServing::Content.new(path)).to respond_to(:collect)
  end

  it "should not retrieve and store its contents when its attributes are collected if the file is a normal file" do
    content = Puppet::FileServing::Content.new(path)

    result = "foo"
    Puppet::FileSystem.expects(:lstat).with(path).returns stub('stat', :ftype => "file")
    File.expects(:read).with(path).never
    content.collect

    expect(content.instance_variable_get("@content")).to be_nil
  end

  it "should not attempt to retrieve its contents if the file is a directory" do
    content = Puppet::FileServing::Content.new(path)

    result = "foo"
    Puppet::FileSystem.expects(:lstat).with(path).returns stub('stat', :ftype => "directory")
    File.expects(:read).with(path).never
    content.collect

    expect(content.instance_variable_get("@content")).to be_nil
  end

  it "should have a method for setting its content" do
    content = Puppet::FileServing::Content.new(path)
    expect(content).to respond_to(:content=)
  end

  it "should make content available when set externally" do
    content = Puppet::FileServing::Content.new(path)
    content.content = "foo/bar"
    expect(content.content).to eq("foo/bar")
  end

  it "should be able to create a content instance from raw file contents" do
    expect(Puppet::FileServing::Content).to respond_to(:from_raw)
  end

  it "should create an instance with a fake file name and correct content when converting from raw" do
    instance = mock 'instance'
    Puppet::FileServing::Content.expects(:new).with("/this/is/a/fake/path").returns instance

    instance.expects(:content=).with "foo/bar"

    expect(Puppet::FileServing::Content.from_raw("foo/bar")).to equal(instance)
  end

  it "should return an opened File when converted to raw" do
    content = Puppet::FileServing::Content.new(path)

    File.expects(:new).with(path, "rb").returns :file

    expect(content.to_raw).to eq(:file)
  end
end

describe Puppet::FileServing::Content, "when returning the contents" do
  let(:path) { File.expand_path('/my/path') }
  let(:content) { Puppet::FileServing::Content.new(path, :links => :follow) }

  it "should fail if the file is a symlink and links are set to :manage" do
    content.links = :manage
    Puppet::FileSystem.expects(:lstat).with(path).returns stub("stat", :ftype => "symlink")
    expect { content.content }.to raise_error(ArgumentError)
  end

  it "should fail if a path is not set" do
    expect { content.content }.to raise_error(Errno::ENOENT)
  end

  it "should raise Errno::ENOENT if the file is absent" do
    content.path = File.expand_path("/there/is/absolutely/no/chance/that/this/path/exists")
    expect { content.content }.to raise_error(Errno::ENOENT)
  end

  it "should return the contents of the path if the file exists" do
    Puppet::FileSystem.expects(:stat).with(path).returns(stub('stat', :ftype => 'file'))
    Puppet::FileSystem.expects(:binread).with(path).returns(:mycontent)
    expect(content.content).to eq(:mycontent)
  end

  it "should cache the returned contents" do
    Puppet::FileSystem.expects(:stat).with(path).returns(stub('stat', :ftype => 'file'))
    Puppet::FileSystem.expects(:binread).with(path).returns(:mycontent)
    content.content
    # The second run would throw a failure if the content weren't being cached.
    content.content
  end
end
