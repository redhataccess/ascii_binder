require 'fileutils'
require 'git'
require 'open3'
require 'tmpdir'
require 'yaml'

module Helpers
  def gem_root
    File.expand_path '../../..', __FILE__
  end

  def run_command(command,args=[],repo_dir=nil)
    if repo_dir.nil?
      repo_dir = working_dir
    end
    instructions = [File.join(gem_root,'bin','asciibinder'),command]
    instructions.concat(args)
    instructions << repo_dir
    stdout_str, stderr_str, status = Open3.capture3(instructions.join(' '))
    return { :stdout => stdout_str, :stderr => stderr_str, :status => status }
  end

  def print_output(command_output)
    puts "STDOUT:\n#{command_output[:stdout]}\n\n"
    puts "STDERR:\n#{command_output[:stderr]}\n\n"
    puts "EXIT CODE: #{command_output[:status].exitstatus}\n\n"
  end

  def working_dir
    @working_dir ||= begin
      working_dir = Dir.mktmpdir('ascii_binder-cucumber')
      track_tmp_dir(working_dir)
      FileUtils.rm_rf(working_dir)
      working_dir
    end
  end

  def distro_map
    @distro_map ||= YAML.load_file(File.join(docs_root,'_distro_map.yml'))
  end

  def topic_map
    # Normally we want to read the topic map from each branch. In our test setup,
    # each branch has an identical topic map, so we can get away with this for now.
    @topic_map ||= YAML.load_stream(open(File.join(docs_root,'_topic_map.yml')))
  end

  def alias_files
    @alias_files ||= ['aliases/a_to_a.html','aliases/a_to_e.html']
  end

  def preview_dir
    @preview_dir ||= File.join(docs_root,'_preview')
  end

  def package_dir
    @package_dir ||= File.join(docs_root,'_package')
  end

  def repo_template_dir
    @repo_template_dir ||= File.join(gem_root,'templates')
  end

  def test_distro_dir
    @test_distro_dir ||= File.join(gem_root,'features','support','test_distro')
  end

  def track_tmp_dir(tmp_dir)
    if @tracked_tmp_dirs.nil?
      @tracked_tmp_dirs = []
    end
    @tracked_tmp_dirs << tmp_dir unless @tracked_tmp_dirs.include?(tmp_dir)
  end

  def clean_tracked_dirs
    @tracked_tmp_dirs.each do |dir|
      FileUtils.rm_rf(dir)
    end
  end

  def find_html_files(dir)
    `cd #{dir} && find .`.split("\n").select{ |item| item.end_with?('.html') }.map{ |item| item[2..-1] }
  end

  def files_diff_explanation(gen_paths,cfg_paths)
    gen_extras  = (gen_paths-cfg_paths)
    cfg_extras  = (cfg_paths-gen_paths)
    explanation = ''
    if gen_extras.length > 0
      explanation = "Unexpected extra files were generated:\n\t* " + gen_extras.join("\n\t* ")
    end
    if cfg_extras.length > 0
      if explanation.length > 0
        explanation = explanation + "\n"
      end
      explanation = explanation + "Expected files were not generated:\n\t* " + cfg_extras.join("\n\t* ")
    end
    return explanation
  end

  def actual_preview_info
    all_preview_paths = find_html_files(preview_dir)

    map = {}
    dirmatch = {}
    distro_map.each do |distro,distro_info|
      map[distro] = {}
      distro_info['branches'].each do |branch,branch_info|
        map[distro][branch] = []
        dirmatch["#{distro}/#{branch_info['dir']}"] = { :distro => distro, :branch => branch }
      end
    end

    populated_distros  = []
    populated_branches = []
    populated_pages    = []
    all_preview_paths.each do |preview_path|
      found_dirmatch = false
      dirmatch.each do |branch_path,db_keys|
        next unless preview_path.start_with?(branch_path)
        found_dirmatch = true
        map[db_keys[:distro]][db_keys[:branch]] << preview_path
        populated_distros << db_keys[:distro]
        populated_branches << db_keys[:branch]
        populated_pages << preview_path.split('/')[2..-1].join('/')
        break
      end
      unless found_dirmatch
        puts "ERROR: unexpected output file '#{preview_path}'"
        exit 1
      end
    end

    map.keys.each do |distro|
      map[distro].keys.each do |branch|
        map[distro][branch].sort!
      end
    end

    return {
      :map      => map,
      :distros  => populated_distros.uniq,
      :branches => populated_branches.uniq,
      :pages    => populated_pages.uniq,
    }
  end

  def actual_site_map
    all_site_paths = find_html_files(package_dir)

    map = {}
    dirmatch = {}
    distro_map.each do |distro,distro_info|
      site = distro_info['site']
      unless map.has_key?(site)
        map[site] = {}
      end
      map[site][distro] = {}
      distro_info['branches'].each do |branch,branch_info|
        map[site][distro][branch] = []
        dirmatch["#{distro_info['site']}/#{branch_info['dir']}"] = {
          :distro => distro,
          :branch => branch,
          :site   => site,
        }
      end
    end

    all_site_paths.each do |site_path|
      # skip the top-level index.html file in each site.
      path_parts = site_path.split('/')
      next if path_parts.length == 2 and path_parts[1] == 'index.html'

      found_dirmatch = false
      dirmatch.each do |branch_path,db_keys|
        next unless site_path.start_with?(branch_path)
        found_dirmatch = true
        map[db_keys[:site]][db_keys[:distro]][db_keys[:branch]] << site_path
        break
      end
      unless found_dirmatch
        puts "ERROR: unexpected output file '#{site_path}'"
        exit 1
      end
    end

    map.keys.each do |site|
      map[site].keys.each do |distro|
        map[site][distro].keys.each do |branch|
          map[site][distro][branch].sort!
        end
      end
    end

    return map
  end

  def distro_preview_path_map
    map = {}
    distro_map.each do |distro,distro_info|
      map[distro] = {}
      distro_info['branches'].each do |branch,branch_info|
        map[distro][branch] = []
        topic_map.each do |topic_node|
          map[distro][branch].concat(topic_paths(distro,topic_node).map{ |subpath| "#{distro}/#{branch_info['dir']}/#{subpath}" })
        end
        map[distro][branch].sort!
      end
    end
    return map
  end

  def distro_site_path_map
    map = {}
    distro_map.each do |distro,distro_info|
      site = distro_info['site']
      unless map.has_key?(site)
        map[site] = {}
      end
      map[site][distro] = {}
      distro_info['branches'].each do |branch,branch_info|
        map[site][distro][branch] = []
        topic_map.each do |topic_node|
          map[site][distro][branch].concat(topic_paths(distro,topic_node).map{ |subpath| "#{site}/#{branch_info['dir']}/#{subpath}" })
        end
        map[site][distro][branch].sort!
      end
    end
    return map
  end

  def topic_paths(distro,topic_node)
    # First, determine if this topic node should be included for this distro.
    if topic_node.has_key?('Distros')
      found_distro = false
      included_distros = topic_node['Distros'].split(',')
      included_distros.each do |check_distro|
        if check_distro.include?('*') and File.fnmatch(check_distro,distro)
          found_distro = true
          break
        elsif check_distro == distro
          found_distro = true
          break
        end
      end
      unless found_distro
        return []
      end
    end

    if topic_node.has_key?('File')
      # This topic node is a topic "leaf"; return it with '.html' as the extension.
      filename = topic_node['File'].split('.')[0]
      return ["#{filename}.html"]
    elsif topic_node.has_key?('Dir')
      dirpath = topic_node['Dir']
      subtopics = []
      topic_node['Topics'].each do |subtopic_node|
        subtopics.concat(topic_paths(distro,subtopic_node))
      end
      return subtopics.map{ |subpath| "#{dirpath}/#{subpath}" }
    else
      puts "ERROR: Malformed topic node. #{topic_node.inspect}"
      exit 1
    end
  end

  def set_initial_working_branch(branch)
    @initial_working_branch = branch
  end

  def initial_working_branch
    @initial_working_branch ||= nil
  end

  def using_offset_docs_root?
    @using_offset_docs_root
  end

  def docs_root
    using_offset_docs_root? ? File.join(working_dir,'docs') : working_dir
  end

  def initialize_test_repo(valid,multiple_distros=false,offset_docs_root=false)
    unless valid
      FileUtils.mkdir(working_dir)
    else
      status_check(run_command('create'),'Could not initialize test repo.')
      if multiple_distros
        FileUtils.cp_r(File.join(test_distro_dir,'.'),working_dir)
      end
      if offset_docs_root
        @using_offset_docs_root = true
        entries = Dir.entries(working_dir).select{ |item| not item.start_with?('.') }
        system("cd #{working_dir} && mkdir docs")
        entries.each do |entry|
          system("cd #{working_dir} && mv #{entry} docs")
        end
      end
      system("cd #{working_dir} && git add . > /dev/null && git commit -am 'test commit' > /dev/null")
      if multiple_distros
        system("cd #{working_dir} && git checkout -b branch1 > /dev/null 2>&1 && git checkout -b branch2 > /dev/null 2>&1 && git checkout main > /dev/null 2>&1")
      end
      set_initial_working_branch('main')
    end
    working_dir
  end

  def invalidate_distro_map
      invalid_map = File.join(gem_root,'features','support','_invalid_distro_map.yml')
      FileUtils.cp(invalid_map,File.join(docs_root,'_distro_map.yml'))
      system("cd #{working_dir} && git add . > /dev/null && git commit -am 'Commit invalid distro map' > /dev/null")
  end

  def invalidate_topic_map
      invalid_map = File.join(gem_root,'features','support','_invalid_alias_topic_map.yml')
      FileUtils.cp(invalid_map,File.join(docs_root,'_topic_map.yml'))
      system("cd #{working_dir} && git add . > /dev/null && git commit -am 'Commit invalid alias topic map' > /dev/null")
  end

  def initialize_remote_repo
    remote_dir = Dir.mktmpdir('ascii_binder-cucumber-remote')
    FileUtils.rm_rf(remote_dir)
    track_tmp_dir(remote_dir)
    if run_command('create',[],remote_dir)[:status].exitstatus == 0
      clone_map = File.join(gem_root,'features','support','_clone_distro_map.yml')
      FileUtils.cp(clone_map,File.join(remote_dir,'_distro_map.yml'))
      system("cd #{remote_dir} && git add . > /dev/null && git commit -am 'remote commit' > /dev/null && git checkout -b branch1 > /dev/null 2>&1 && git checkout main > /dev/null 2>&1")
    else
      puts "ERROR: Could not initialize remote repo"
      exit 1
    end
    remote_dir
  end

  def status_check(step_output,error_message)
    unless step_output[:status].exitstatus == 0
      puts "ERROR: #{error_message}"
      print_output(step_output)
      exit 1
    end
  end

  def build_check(scope,target='')
    # Initial state of check_map matches ':default' scope
    check_map = {
      :current_branch_only   => true,
      :specified_distro_only => false,
      :specified_page_only   => false,
    }
    case scope
    when :default
      # Change nothing
    when :distro
      check_map[:specified_distro_only] = true
    when :all_branches
      check_map[:current_branch_only] = false
    when :page
      check_map[:specified_page_only] = true
    else
      puts "ERROR: Build scope '#{scope}' not recognized."
      exit 1
    end

    # Make sure the build finished on the same branch where it started.
    git = Git.open(working_dir)
    current_working_branch = git.current_branch
    unless current_working_branch == initial_working_branch
      puts "ERROR: Build operation started on branch '#{initial_working_branch}' but ended on branch '#{current_working_branch}'"
      exit 1
    end

    # generate the expected preview paths for each full distro + branch combo
    all_paths_map = distro_preview_path_map

    # get all of the paths in the actual preview directory
    real_preview_info = actual_preview_info

    gen_paths_map = real_preview_info[:map]
    branch_count  = real_preview_info[:branches].length
    distro_count  = real_preview_info[:distros].length
    page_count    = real_preview_info[:pages].length
    target_distro = real_preview_info[:distros][0]
    target_page   = real_preview_info[:pages][0].split('/').join(':').split('.')[0]

    if distro_count == 0 or branch_count == 0
      puts "ERROR: A build operation should produce at least one distro / branch preview."
      exit 1
    end

    # Compare branches by count
    if branch_count > 1 and check_map[:current_branch_only]
      puts "ERROR: Expected behavior for '#{scope}' scope is to build current working branch only."
      exit 1
    elsif branch_count == 1 and not check_map[:current_branch_only]
      puts "ERROR: Expected behavior for '#{scope}' scope is to build all local branches."
      exit 1
    end

    # Compare distros by count
    if distro_count > 1 and check_map[:specified_distro_only]
      puts "ERROR: Expected behavior for '#{scope}' scope is to build specified branch ('#{target}') only."
      exit 1
    elsif distro_count == 1
      if not check_map[:specified_distro_only]
        puts "ERROR: Expected behavior for '#{scope}' scope is to build all distros."
        exit 1
      elsif not target_distro == target
        puts "ERROR: The build did not run for the expected target distro '#{target}' but instead for '#{target_distro}'"
        exit 1
      end
    end

    # Compare pages by count
    if page_count > 1 and check_map[:specified_page_only]
      puts "ERROR: Expected behavior for '#{scope}' is to build the specified page ('#{target}') only."
      exit 1
    elsif page_count == 1
      if not check_map[:specified_page_only]
        puts "ERROR: Expected behavior for '#{scope}' scope is to build all pages."
        exit 1
      elsif not target_page == target
        puts "ERROR: The build did not run for the expected target page '#{target}' but instead for '#{target_page}'"
      end
    end

    # Generated files vs expected files.
    if not check_map[:specified_page_only]
      all_paths_map.keys.each do |distro|
        next if check_map[:specified_distro_only] and not distro == target
        if not gen_paths_map.has_key?(distro)
          puts "ERROR: Expected distro '#{distro}' was not generated for preview."
          exit 1
        end
        all_paths_map[distro].keys.each do |branch|
          next if check_map[:current_branch_only] and not branch == current_working_branch
          if not gen_paths_map[distro].has_key?(branch)
            puts "ERROR: Expected distro / branch combo '#{distro}' / '#{branch}' was not generated for preview."
            exit 1
          end
          # Alias check
          alias_files.each do |afile|
            genmatches = gen_paths_map[distro][branch].select{ |i| i.end_with?(afile) }
            if genmatches.length == 0
              puts "ERROR: Alias file '#{afile}' was not generated for distro / branch combo '#{distro}' / '#{branch}'."
              exit 1
            elsif genmatches.length > 1
              puts "ERROR: Alias file '#{afile}' found more than once in generated output: #{genmatches.inspect}"
              exit 1
            end
          end
          if not gen_paths_map[distro][branch] == all_paths_map[distro][branch]
            explanation = files_diff_explanation(gen_paths_map[distro][branch],all_paths_map[distro][branch])
            puts "ERROR: Mismatch between expected and actual preview file paths for distro / branch combo '#{distro}' / '#{branch}'.\n#{explanation}"
            exit 1
          end
        end
      end
    end
  end

  def package_check(target_site='')
    all_paths_map = distro_site_path_map
    real_site_map = actual_site_map

    real_site_map.keys.each do |site|
      real_site_map[site].keys.each do |distro|
        real_site_map[site][distro].keys.each do |branch|
          # If a target site was specified and any content was generated for a different site, raise an error.
          if not target_site == '' and not site == target_site and real_site_map[site][distro][branch].length > 0
            puts "ERROR: Content was generated for site '#{site}' even though it was only expected for site '#{target_site}'"
            exit 1
          end
          # Alias check
          if real_site_map[site][distro][branch].length > 0 and all_paths_map[site][distro][branch].length > 0
            alias_files.each do |afile|
              genmatches = real_site_map[site][distro][branch].select{ |i| i.end_with?(afile) }
              if genmatches.length == 0
                puts "ERROR: Alias file '#{afile}' was not generated for site / distro / branch combo '#{site}' / '#{distro}' / '#{branch}'."
                exit 1
              elsif genmatches.length > 1
                puts "ERROR: Alias file '#{afile}' found more than once in generated site output: #{genmatches.inspect}"
                exit 1
              end
            end
          end
          # Confirm that what was generated matches what was expected.
          if (target_site == '' or site == target_site) and not real_site_map[site][distro][branch] == all_paths_map[site][distro][branch]
            explanation = files_diff_explanation(real_site_map[site][distro][branch],all_paths_map[site][distro][branch])
            puts "ERROR: Mismatch between expected and actual site file paths for site / distro / branch combo '#{site}' / '#{distro}' / '#{branch}'.\n#{explanation}"
            exit 1
          end
        end
      end

      # Skip the next check for sites that aren't being packaged.
      next unless target_site == '' or site == target_site

      # Finally, confirm that the expected site index page was copied to the site home directory.
      source_page = File.join(docs_root,"index-#{site}.html")
      target_page = File.join(package_dir,site,'index.html')
      unless FileUtils.compare_file(source_page,target_page)
        puts "ERROR: Incorrect site index file contents at '#{target_page}'; expected contents of '#{source_page}'."
        exit 1
      end
    end
  end
end

World(Helpers)

Before do
  working_dir
end

After do
  clean_tracked_dirs
end
