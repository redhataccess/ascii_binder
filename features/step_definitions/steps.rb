require 'ascii_binder/version'
require 'cucumber'
require 'fileutils'
require 'open3'
require 'diff_dirs'

Given(/^an existing repo directory$/) do
  Dir.mkdir(working_dir)
end

Given(/^a nonexistant repo directory$/) do
  working_dir
end

Given(/^a valid AsciiBinder docs repo(.*)$/) do |repo_condition|
  multiple_distros = repo_condition == ' with multiple distros'
  initialize_test_repo(true,multiple_distros)
end

Given(/^an invalid AsciiBinder docs repo$/) do
  initialize_test_repo(false)
end

Given(/^the docs repo contains generated content$/) do
  output    = run_command('package')
  has_error = false
  [preview_dir,package_dir].each do |subdir|
    unless Dir.exist?(subdir)
      puts "ERROR: expected directory '#{subdir}' was not created."
      has_error = true
    end
    unless Dir.entries(subdir).select{ |item| not ['.','..'].include?(item) }.length > 0
      puts "ERROR: directory '#{subdir}' is empty."
      has_error = true
    end
  end
  if has_error
    print_output(output)
    exit 1
  end
end

Given(/^the docs repo contains no generated content$/) do
  [preview_dir,package_dir].each do |subdir|
    next unless Dir.exist?(subdir)
    FileUtils.rm_rf(subdir)
  end
end

Given(/^a nonexistant remote repo$/) do
  @remote_repo_url = 'http://example.com/repo.git'
end

Given(/^an existing remote repo$/) do
  # We're going to set up a local repo as a remote.
  @remote_repo_dir = initialize_remote_repo
  @remote_repo_url = "file://#{@remote_repo_dir}"
end

When(/^the user runs `asciibinder (.+)` on that repo directory$/) do |command_string|
  @command_args = command_string.split(' ')
  command = @command_args.shift
  if command == 'clone'
    @step_output = run_command(command,["-d #{working_dir}"],@remote_repo_url)
  else
    @step_output = run_command(command,@command_args)
  end
end

Then(/^the generated content is removed$/) do
  has_error = false
  [preview_dir,package_dir].each do |subdir|
    unless Dir.exist?(subdir)
      puts "ERROR: expected to find directory '#{subdir}' but didn't"
      has_error = true
    end
    unless Dir.entries(subdir).select{ |item| not ['.','..'].include?(item) }.length == 0
      puts "ERROR: expected directory '#{subdir}' to be empty"
      has_error
    end
  end
  if has_error
    print_output(@step_output)
    exit 1
  end
end

Then(/^the program exits without errors$/) do
  status_check(@step_output,'running `asciibinder clean`.')
end

Then(/^the program exits with a warning$/) do
  if @step_output[:status].exitstatus == 0
    puts "ERROR: testing `asciibinder clean`; expected an exit code other than 0."
    print_output(@step_output)
    exit 1
  end
end

Then(/^the program clones the remote repo into the local directory$/) do
  diffs           = diff_dirs(@remote_repo_dir, working_dir)
  non_git_diffs   = diffs.select{ |entry| not entry[1].start_with?('.git') }
  remote_branches = Git.open(@remote_repo_dir).branches.local.map{ |branch| branch.name }.sort
  local_branches  = Git.open(working_dir).branches.local.map{ |branch| branch.name }.sort
  branch_matches  = remote_branches & local_branches
  unless branch_matches.length == local_branches.length and non_git_diffs.length == 0
    puts "ERROR: cloned repo doesn't match remote repo."
    exit 1
  end
end

Then(/^the program generates a new base docs repo$/) do
  diffs = diff_dirs(repo_template_dir, working_dir)
  unless diffs.length == 1 and diffs[0][0] == :new and diffs[0][1] == '.git'
    puts "ERROR: template repo copy produced differences - #{diffs.inspect}"
    exit 1
  end
end

Then(/^the program displays help information$/) do
  status_check(@step_output,'`asciibinder help` command failed.')
  unless @step_output[:stderr] == '' and @step_output[:stdout].start_with?('Usage:')
    puts "ERROR: unexpected help output"
    print_output(@step_output)
    exit 1
  end
end

Then(/^the program prints the current version of the utility$/) do
  status_check(@step_output,'`asciibinder version` command failed.')
  unless @step_output[:stderr] == '' and @step_output[:stdout].chomp == AsciiBinder::VERSION
    puts "ERROR: unexpected help output"
    print_output(@step_output)
    exit 1
  end
end

Then(/^the program generates preview content for (.+)$/) do |build_target|
  status_check(@step_output,'`asciibinder build` command failed.')
  case build_target
  when 'all distros in the current branch'
    build_check(:default)
  when 'only the `distro_test` distro'
    distro = @command_args.select{ |arg| arg.starts_with?('--distro=') }.map{ |arg| arg.split('=')[1] }[0]
    build_check(:distro,distro)
  when 'all relevant distro/branch combos'
    build_check(:all_branches)
  when 'the specified page in all distros'
    page = @command_args.select{ |arg| arg.starts_with?('--page=') }.map{ |arg| arg.split('=')[1] }[0]
    build_check(:page,page)
  else
    puts "ERROR: unrecognized test case '#{build_target}'"
    exit 1
  end
end

Then(/^the program generates a site directory for (.+) in the distro map$/) do |package_target|
  status_check(@step_output,'`asciibinder package` command failed.')
  case package_target
  when 'each site'
    package_check()
  when 'only the `test` site'
    site = @command_args.select{ |arg| arg.starts_with?('--site=') }.map{ |arg| arg.split('=')[1] }[0]
    package_check(site)
  else
    puts "ERROR: unrecognized test case '#{build_target}'"
    exit 1
  end
end
