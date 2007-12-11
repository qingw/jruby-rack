#--
# **** BEGIN LICENSE BLOCK *****
# Version: CPL 1.0/GPL 2.0/LGPL 2.1
#
# The contents of this file are subject to the Common Public
# License Version 1.0 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.eclipse.org/legal/cpl-v10.html
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# Copyright (C) 2007 Sun Microsystems, Inc.
#
# Alternatively, the contents of this file may be used under the terms of
# either of the GNU General Public License Version 2 or later (the "GPL"),
# or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
# in which case the provisions of the GPL or the LGPL are applicable instead
# of those above. If you wish to allow use of your version of this file only
# under the terms of either the GPL or the LGPL, and not to allow others to
# use your version of this file under the terms of the CPL, indicate your
# decision by deleting the provisions above and replace them with the notice
# and other provisions required by the GPL or the LGPL. If you do not delete
# the provisions above, a recipient may use your version of this file under
# the terms of any one of the CPL, the GPL or the LGPL.
# **** END LICENSE BLOCK ****
#++

require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.DefaultRackApplication

describe DefaultRackApplication, "call" do
  it "should invoke the call method on the ruby object and return the rack result" do
    servlet_request = mock("servlet request")
    rack_result = org.jruby.rack.RackResult.impl {}

    ruby_object = mock "application"
    ruby_object.should_receive(:call).with(servlet_request).and_return rack_result
    
    application = DefaultRackApplication.new(ruby_object)
    application.call(servlet_request).should == rack_result
  end
end

import org.jruby.rack.DefaultRackApplicationFactory

describe DefaultRackApplicationFactory, "newRuntime" do
  before :each do
    @servlet_context.stub!(:getInitParameter).and_return nil
    @app_factory = DefaultRackApplicationFactory.new
    @app_factory.init(@servlet_context)
  end

  it "should create a new Ruby runtime with the rack environment pre-loaded" do
    runtime = @app_factory.newRuntime
    lazy_string = proc {|v| "(begin; #{v}; rescue Exception => e; e.class; end).name"}
    @app_factory.verify(runtime, lazy_string.call("Rack")).should == "Rack"
    @app_factory.verify(runtime, lazy_string.call("Rack::Handler::Servlet")
      ).should == "Rack::Handler::Servlet"
    @app_factory.verify(runtime, lazy_string.call("Rack::Handler::Bogus")
      ).should_not == "Rack::Handler::Bogus"
  end

  it "should initialize the $servlet_context global variable" do
    runtime = @app_factory.newRuntime
    @app_factory.verify(runtime, "defined?($servlet_context)").should_not be_empty
  end
end

describe DefaultRackApplicationFactory, "newApplication" do
  it "should create a Ruby object from the script snippet given" do
    @servlet_context.stub!(:getInitParameter).and_return("require 'rack/lobster'; Rack::Lobster.new")
    app_factory = DefaultRackApplicationFactory.new
    app_factory.init(@servlet_context)
    object = app_factory.newApplication
    object.respond_to?(:call).should == true
  end
end

import org.jruby.rack.PoolingRackApplicationFactory

describe PoolingRackApplicationFactory do
  before :each do
    @factory = mock "factory"
    @pool = PoolingRackApplicationFactory.new @factory
  end

  it "should initialize the delegate factory when initialized" do
    context = mock("servlet context")
    @factory.should_receive(:init).with(context)
    @pool.init(context)
  end

  it "should start out empty" do
    @pool.getApplicationPool.should be_empty
  end

  it "should create a new application when empty" do
    app = mock "app"
    @factory.should_receive(:newApplication).and_return app
    @pool.newApplication.should == app
  end

  it "should return an existing application when not empty" do
    app = mock "app"
    @pool.finishedWithApplication app
    @pool.getApplicationPool.should_not be_empty
    @pool.newApplication.should == app
  end
end