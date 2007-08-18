# -*- ruby -*-

require 'rubygems'
require 'hoe'
$LOAD_PATH.unshift('./lib')
require 'active_ldap'

project = Hoe.new('ruby-activeldap', ActiveLdap::VERSION) do |project|
  project.rubyforge_name = 'ruby-activeldap'
  project.author = ['Will Drewry', 'Kouhei Sutou']
  project.email = ['will@alum.bu.edu', 'kou@cozmixng.org']
  project.summary = 'Ruby/ActiveLdap is a object-oriented API to LDAP'
  project.url = 'http://rubyforge.org/projects/ruby-activeldap/'
  project.test_globs = ['test/test_*.rb']
  project.changes = project.paragraphs_of('CHANGES', 0..1).join("\n\n")
  project.extra_deps = [['log4r', '>= 1.0.4'], 'activerecord']
  project.spec_extras = {
    :requirements => ['ruby-ldap >= 0.8.2', '(Open)LDAP server'],
    :autorequire => 'active_ldap',
    :executables => [],
  }
  project.description = String.new(<<-EOF)
    'Ruby/ActiveLdap' is a ruby extension library which provides a clean
    objected oriented interface to the Ruby/LDAP library.  It was inspired
    by ActiveRecord. This is not nearly as clean or as flexible as
    ActiveRecord, but it is still trivial to define new objects and manipulate
    them with minimal difficulty.
  EOF
end

publish_docs_actions = task(:publish_docs).instance_variable_get("@actions")
original_project_name = nil
before_publish_docs = Proc.new do
  original_project_name = project.name
  project.name = "doc"
end
after_publish_docs = Proc.new do
  project.name = original_project_name
end
publish_docs_actions.unshift(before_publish_docs)
publish_docs_actions.push(after_publish_docs)

# fix Hoe's incorrect guess.
project.spec.executables.clear
project.bin_files = project.spec.files.grep(/^bin/)

# fix Hoe's install and uninstall task.
task(:install).instance_variable_get("@actions").clear
task(:uninstall).instance_variable_get("@actions").clear

task :install do
  [
   [project.lib_files, "lib", Hoe::RUBYLIB, 0444],
   [project.bin_files, "bin", File.join(Hoe::PREFIX, 'bin'), 0555]
  ].each do |files, prefix, dest, mode|
    FileUtils.mkdir_p dest unless test ?d, dest
    files.each do |file|
      base = File.dirname(file.sub(/^#{prefix}#{File::SEPARATOR}/, ''))
      _dest = File.join(dest, base)
      FileUtils.mkdir_p _dest unless test ?d, _dest
      install file, _dest, :mode => mode
    end
  end
end

desc 'Uninstall the package.'
task :uninstall do
  Dir.chdir Hoe::RUBYLIB do
    rm_f project.lib_files.collect {|f| f.sub(/^lib#{File::SEPARATOR}/, '')}
  end
  Dir.chdir File.join(Hoe::PREFIX, 'bin') do
    rm_f project.bin_files.collect {|f| f.sub(/^bin#{File::SEPARATOR}/, '')}
  end
end

desc 'Tag the repository for release.'
task :tag do
  system "svn copy -m 'New release tag' https://ruby-activeldap.googlecode.com/svn/trunk https://ruby-activeldap.googlecode.com/svn/tags/r#{ActiveLdap::VERSION}"
end


desc "Update *.po/*.pot files and create *.mo from *.po files"
task :gettext => ["gettext:po:update", "gettext:mo:create"]

namespace :gettext do
  desc "Setup environment for GetText"
  task :environment do
    require "gettext/utils"
  end

  namespace :po do
    desc "Update po/pot files (GetText)"
    task :update => "gettext:environment" do
      require 'active_ldap/get_text/parser'
      dummy_file = "@@@dummy-for-active-ldap@@@"
      parser = Object.new
      parser.instance_eval do
        @parser = ActiveLdap::GetText::Parser.new
        @dummy_file = dummy_file
      end
      def parser.target?(file)
        file == @dummy_file
      end
      def parser.parse(file, targets)
        @parser.extract_all_in_schema(targets)
      end

      GetText::RGetText.add_parser(parser)
      GetText.update_pofiles("active-ldap",
                             [dummy_file] + Dir.glob("lib/**/*.rb"),
                             "Ruby/ActiveLdap #{ActiveLdap::VERSION}")
    end
  end

  namespace :mo do
    desc "Create *.mo from *.po (GetText)"
    task :create => "gettext:environment" do
      GetText.create_mofiles(false)
    end
  end
end

task(:gem).prerequisites.unshift("gettext:mo:create")

# vim: syntax=ruby