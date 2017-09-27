require 'rake'
require 'ascii_binder'

include AsciiBinder::Engine
include AsciiBinder::Helpers

desc "Build the documentation"
task :build, :build_distro do |task,args|
  # Figure out which distros we are building.
  # A blank value here == all distros
  set_docs_root_dir(git_root_dir)
  set_log_level(:warn)
  build_distro = args[:build_distro] || ''
  generate_docs(:all,build_distro,nil)
end

desc "Package the documentation"
task :package, :package_site do |task,args|
  set_docs_root_dir(git_root_dir)
  set_log_level(:warn)
  package_site = args[:package_site] || ''
  Rake::Task["clean"].invoke
  Rake::Task["build"].invoke
  package_docs(package_site)
end

desc "Build the documentation and refresh the page"
task :refresh_page, :single_page do |task,args|
  set_docs_root_dir(git_root_dir)
  set_log_level(:warn)
  generate_docs(:working_only,'',args[:single_page])
end

desc "Clean all build artifacts"
task :clean do
  sh "rm -rf _preview/* _package/*" do |ok,res|
    if ! ok
      puts "Nothing to clean."
    end
  end
end
