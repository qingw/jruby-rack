require 'rbconfig'

module Buildr
  class RSpec < TestFramework::Base
    REQUIRES = [(defined?(JRUBY) ? JRUBY : "org.jruby:jruby-complete:jar:1.1RC1")]

    class << self
      def applies_to?(project) #:nodoc:
        File.directory?(project._("spec"))
      end
    end

    def tests(task, dependencies) #:nodoc:      
      FileList[ENV["SPEC"] || "#{task.project._('spec')}/**/*_spec.rb"]
    end

    def run(tests, task, dependencies) #:nodoc:
      class << task; public :project; end # project should probably be public on task
      cmd_options = task.options.only(:properties, :java_args)
      cmd_options.update :classpath => dependencies, :project => task.project
      install_gems(cmd_options)

      report_dir = task.report_to.to_s
      FileUtils.rm_rf report_dir
      ENV['CI_REPORTS'] = report_dir

      jruby("-Ilib", "-S", "spec",
      "--require", gem_path(task.project, "ci_reporter", "lib/ci/reporter/rake/rspec_loader"),
      "--format", "CI::Reporter::RSpecDoc", tests,   
      "--colour",
      cmd_options.merge({:name => "RSpec"}))
      tests
    end

    private
    def jruby_home(project)
      @jruby_home ||= RUBY_PLATFORM =~ /java/ ? Config::CONFIG['prefix'] : project._(".jruby")
    end

    def gem_path(project, gem_name, *additional)
      dir = Dir["#{jruby_home(project)}/lib/ruby/gems/1.8/gems/#{gem_name}*"].to_a.first
      dir = File.join(dir, *additional) unless additional.empty?
      dir
    end

    def required_gems(options)
      ["ci_reporter", options[:required_gems]].flatten.compact
    end

    def jruby(*args)
      java_args = ["org.jruby.Main", *args]
      java_args << {} unless Hash === args.last
      cmd_options = java_args.last
      project = cmd_options.delete(:project)
      if RUBY_PLATFORM =~ /java/
        # when run from within JRuby, use jars in launched-JRuby's classpath rather than the
        # stated dependency
        cmd_options[:classpath].delete_if {|e| File.basename(e) =~ /^jruby-complete-.*\.jar$/ }
        cmd_options[:classpath].unshift(
          *(java.lang.System.getProperty("java.class.path").split(File::PATH_SEPARATOR)))
      end
      cmd_options[:java_args] ||= []
      cmd_options[:java_args] << "-Xmx512m" unless cmd_options[:java_args].detect {|a| a =~ /^-Xmx/}
      cmd_options[:properties] ||= {}
      cmd_options[:properties]["jruby.home"] = jruby_home(project)
      Java::Commands.java(*java_args)
    end

    def install_gems(options)
      unless required_gems(options).all? {|g| gem_path(options[:project], g)}
        args = ["-S", "maybe_install_gems", *required_gems(options)]
        args << {:name => "JRuby Setup"}.merge(options)
        jruby(*args)
      end
    end
  end
end

Buildr::TestFramework << Buildr::RSpec