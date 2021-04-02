require 'ascii_binder/distro_branch'
require 'ascii_binder/distro_map'
require 'ascii_binder/helpers'
require 'ascii_binder/site_map'
require 'ascii_binder/template_renderer'
require 'ascii_binder/topic_map'
require 'asciidoctor'
require 'asciidoctor/cli'
require 'asciidoctor-diagram'
require 'fileutils'
require 'find'
require 'git'
require 'pathname'
require 'sitemap_generator'
require 'trollop'
require 'yaml'

include AsciiBinder::Helpers

module AsciiBinder
  module Engine

    def build_date
      Time.now.utc
    end

    def git
      @git ||= Git.open(git_root_dir)
    end

    def git_checkout branch_name
      target_branch = git.branches.local.select{ |b| b.name == branch_name }[0]
      if not target_branch.nil? and not target_branch.current
        target_branch.checkout
      end
    end

    def git_stash_all
      # See if there are any changes in need of stashing
      @stash_needed = `cd #{git_root_dir} && git status --porcelain` !~ /^\s*$/
      if @stash_needed
        log_unknown("Stashing uncommited changes and files in working branch.")
        `cd #{docs_root_dir} && git stash -u`
      end
    end

    def git_apply_and_drop
      return unless @stash_needed
      log_unknown("Re-applying uncommitted changes and files to working branch.")
      if system("cd #{docs_root_dir} && git stash pop")
        log_unknown("Stash application successful.")
      else
        log_error("Could not apply stashed code. Run `git stash apply` manually.")
      end
      @stash_needed = false
    end

    # Returns the local git branches; current branch is always first
    def local_branches
      @local_branches ||= begin
        branches = []
        if not git.branches.local.empty?
          branches << git.branches.local.select{ |b| b.current }[0].name
          branches << git.branches.local.select{ |b| not b.current }.map{ |b| b.name }
        end
        branches.flatten
      end
    end

    def working_branch
      @working_branch ||= local_branches[0]
    end

    def dir_empty?(dir)
      Dir.entries(dir).select{ |f| not f.start_with?('.') }.empty?
    end


    # Protip: Don't cache these! The topic map needs to be reread every time we change branches.
    def topic_map_file
      topic_file = TOPIC_MAP_FILENAME
      unless File.exist?(File.join(docs_root_dir,topic_file))
        # The new filename '_topic_map.yml' couldn't be found;
        # switch to the old one and warn the user.
        topic_file = BUILD_FILENAME
        unless File.exist?(File.join(docs_root_dir,topic_file))
          # Critical error - no topic map file at all.
          Trollop::die "Could not find any topic map file ('#{TOPIC_MAP_FILENAME}' or '#{BUILD_FILENAME}') at #{docs_root_dir} in branch '#{git.branch}'"
        end
        log_warn("'#{BUILD_FILENAME}' is a deprecated filename. Rename this to '#{TOPIC_MAP_FILENAME}'.")
      end
      topic_file
    end

    def topic_map
      topic_map = AsciiBinder::TopicMap.new(topic_map_file,distro_map.distro_keys)
      unless topic_map.is_valid?
        errors = topic_map.errors
        Trollop::die "The topic map file at '#{topic_map_file}' contains the following errors:\n- " + errors.join("\n- ") + "\n"
      end
      return topic_map
    end

    def create_new_repo
      gem_template_dir = File.join(gem_root_dir,"templates")

      # Create the new repo dir
      FileUtils.mkdir_p(docs_root_dir)

      # Copy the basic repo content into the new repo dir
      Find.find(gem_template_dir).each do |path|
        next if path == gem_template_dir
        src_path = Pathname.new(path)
        tgt_path = src_path.sub(gem_template_dir,docs_root_dir)
        if src_path.directory?
          FileUtils.mkdir_p(tgt_path.to_s)
        else
          FileUtils.cp src_path.to_s, tgt_path.to_s
        end
      end

      # Initialize the git repo
      Git.init(docs_root_dir)
    end

    def find_topic_files
      file_list = []
      Find.find(docs_root_dir).each do |path|
        # Only consider .adoc files and ignore README, and anything in
        # directories whose names begin with 'old' or '_' (underscore)
        next if path.nil? or not path =~ /.*\.adoc/ or path =~ /README/ or path =~ /\/old\// or path =~ /\/_/
        src_path = Pathname.new(path).sub(docs_root_dir,'').to_s
        next if src_path.split('/').length < 3
        file_list << src_path
      end
      file_list.map{ |path| File.join(File.dirname(path),File.basename(path,'.adoc'))[1..-1] }
    end

    def remove_found_topic_files(branch,branch_topic_map,branch_topic_files)
      nonexistent_topics = []
      branch_topic_map.filepaths.each do |topic_map_filepath|
        result = branch_topic_files.delete(topic_map_filepath)
        if result.nil?
          nonexistent_topics << topic_map_filepath
        end
      end
      if nonexistent_topics.length > 0
        if AsciiBinder::LOG_LEVEL > log_levels[:debug]
          log_warn("The #{topic_map_file} file on branch '#{branch}' references #{nonexistent_topics.length} nonexistent topics. Set logging to 'debug' for details.")
        else
          log_warn("The #{topic_map_file} file on branch '#{branch}' references nonexistent topics:\n" + nonexistent_topics.map{ |topic| "- #{topic}" }.join("\n"))
        end
      end
    end

    def distro_map
      @distro_map ||= begin
        distro_map_file = File.join(docs_root_dir, DISTRO_MAP_FILENAME)
        distro_map = AsciiBinder::DistroMap.new(distro_map_file)
        unless distro_map.is_valid?
          errors = distro_map.errors
          Trollop::die "The distro map file at '#{distro_map_file}' contains the following errors:\n- " + errors.join("\n- ") + "\n"
        end
        distro_map
      end
    end

    def site_map
      @site_map ||= AsciiBinder::SiteMap.new(distro_map)
    end

    def branch_group_branches
      @branch_group_branches ||= begin
        group_branches = Hash.new
        group_branches[:working_only] = [local_branches[0]]
        group_branches[:publish]      = distro_map.distro_branches
        site_map.sites.each do |site|
          group_branches["publish_#{site.id}".to_sym] = site.branches
        end
        group_branches[:all] = local_branches
        group_branches
      end
    end

    def page(args)
      # TODO: This process of rebuilding the entire nav for every page will not scale well.
      #       As the doc set increases, we will need to think about refactoring this.
      args[:breadcrumb_root], args[:breadcrumb_group], args[:breadcrumb_subgroup], args[:breadcrumb_topic] = extract_breadcrumbs(args)

      args[:breadcrumb_subgroup_block] = ''
      if args[:breadcrumb_subgroup]
        args[:breadcrumb_subgroup_block] = "<li class=\"hidden-xs active\">#{args[:breadcrumb_subgroup]}</li>"
      end

      args[:subtopic_shim] = '../' * (args[:topic_id].split('::').length - 2)
      args[:subtopic_shim] = '' if args[:subtopic_shim].nil?

      template_path = File.expand_path("#{docs_root_dir}/_templates/page.html.erb")
      template_renderer.render(template_path, args)
    end

    def extract_breadcrumbs(args)
      breadcrumb_root = breadcrumb_group = breadcrumb_subgroup = breadcrumb_topic = nil

      root_group          = args[:navigation].first
      selected_group      = args[:navigation].detect { |group| group[:id] == args[:group_id] }
      selected_subgroup   = selected_group[:topics].detect { |subgroup| subgroup[:id] == args[:subgroup_id] }
      current_is_subtopic = selected_subgroup ? true : false

      if root_group
        root_topic = root_group[:topics].first
        breadcrumb_root = linkify_breadcrumb(root_topic[:path], "#{args[:distro]} #{args[:version]}", current_is_subtopic) if root_topic
      end

      if selected_group
        group_topic = selected_group[:topics].first
        breadcrumb_group = linkify_breadcrumb(group_topic[:path], selected_group[:name], current_is_subtopic) if group_topic

        if selected_subgroup
          subgroup_topic = selected_subgroup[:topics].first
          breadcrumb_subgroup = linkify_breadcrumb(subgroup_topic[:path], selected_subgroup[:name], current_is_subtopic) if subgroup_topic

          selected_topic = selected_subgroup[:topics].detect { |topic| topic[:id] == args[:topic_id] }
          breadcrumb_topic = linkify_breadcrumb(nil, selected_topic[:name], current_is_subtopic) if selected_topic
        else
          selected_topic = selected_group[:topics].detect { |topic| topic[:id] == args[:topic_id] }
          breadcrumb_topic = linkify_breadcrumb(nil, selected_topic[:name], current_is_subtopic) if selected_topic
        end
      end

      return breadcrumb_root, breadcrumb_group, breadcrumb_subgroup, breadcrumb_topic
    end

    def linkify_breadcrumb(href, text, extra_level)
      addl_level = extra_level ? '../' : ''
      href ? "<a href=\"#{addl_level}#{href}\">#{text}</a>" : text
    end

    def asciidoctor_page_attrs(more_attrs=[])
      [
        'source-highlighter=rouge',
        'linkcss!',
        'icons=font',
        'idprefix=',
        'idseparator=-',
        'sectanchors',
        'data-uri',
      ].concat(more_attrs)
    end

    def generate_docs(branch_group,build_distro,single_page)
      # First, test to see if the docs repo has any commits. If the user has just
      # run `asciibinder create`, there will be no commits to work from, yet.
      if local_branches.empty?
        raise "Before you can build the docs, you need at least one commit in your docs repo."
      end

      # Make a filepath in list form from the single_page argument
      single_page_path = []
      if not single_page.nil?
        single_page_path = single_page.split(':')[0].split('/')
        single_page_path << single_page.split(':')[1]
        log_unknown("Rebuilding '#{single_page_path.join('/')}' on branch '#{working_branch}'.")
      end

      if not build_distro == ''
        if not distro_map.include_distro_key?(build_distro)
          exit
        else
          log_unknown("Building only the #{distro_map.get_distro(build_distro).name} distribution.")
        end
      elsif single_page.nil?
        log_unknown("Building all distributions.")
      end

      # Notify the user of missing local branches
      missing_branches = []
      distro_map.distro_branches(build_distro).sort.each do |dbranch|
        next if local_branches.include?(dbranch)
        missing_branches << dbranch
      end
      if missing_branches.length > 0 and single_page.nil?
        message = "The following branches do not exist in your local git repo:\n"
        missing_branches.each do |mbranch|
          message << "- #{mbranch}\n"
        end
        message << "The build will proceed but these branches will not be generated."
        log_warn(message)
      end

      # Generate all distros for all branches in the indicated branch group
      branch_group_branches[branch_group].each do |local_branch|
        # Skip known missing branches; this will only come up for the :publish branch group
        next if missing_branches.include?(local_branch)

        # Single-page regen only occurs for the working branch
        if not local_branch == working_branch
          if single_page.nil?
            # Checkout the branch
            log_unknown("CHANGING TO BRANCH '#{local_branch}'")
            git_checkout(local_branch)
          else
            next
          end
        end

        # Note the image files checked in to this branch.
        branch_image_files = Find.find(docs_root_dir).select{ |path| not path.nil? and (path =~ /.*\.png$/ or path =~ /.*\.png\.cache$/) }

        first_branch = single_page.nil?

        if local_branch =~ /^\(detached from .*\)/
          local_branch = 'detached'
        end

        # The branch_orphan_files list starts with the set of all
        # .adoc files found in the repo, and will be whittled
        # down from there.
        branch_orphan_files = find_topic_files
        branch_topic_map    = topic_map
        remove_found_topic_files(local_branch,branch_topic_map,branch_orphan_files)

        if branch_orphan_files.length > 0 and single_page.nil?
          if AsciiBinder::LOG_LEVEL > log_levels[:debug]
            log_warn("Branch #{local_branch} includes #{branch_orphan_files.length} files that are not referenced in the #{topic_map_file} file. Set logging to 'debug' for details.")
          else
            log_warn("Branch '#{local_branch}' includes the following .adoc files that are not referenced in the #{topic_map_file} file:\n" + branch_orphan_files.map{ |file| "- #{file}" }.join("\n"))
          end
        end

        # Run all distros.
        distro_map.distros.each do |distro|
          if not build_distro == ''
            # Only building a single distro; build for all indicated branches, skip the others.
            next unless build_distro == distro.id
          else
            current_distro_branches = distro_map.distro_branches(distro.id)

            # In publish mode we only build "valid" distro-branch combos from the distro map
            if branch_group.to_s.start_with?("publish") and not current_distro_branches.include?(local_branch)
              next
            end

            # In "build all" mode we build every distro on the working branch plus the publish distro-branch combos
            if branch_group == :all and not local_branch == working_branch and not current_distro_branches.include?(local_branch)
              next
            end
          end

          # Get the current distro / branch object
          branch_config = AsciiBinder::DistroBranch.new('',{ "name" => "Branch Build", "dir" => local_branch },distro)
          dev_branch    = true
          if distro.branch_ids.include?(local_branch)
            branch_config = distro.branch(local_branch)
            dev_branch    = false
          end

          if first_branch
            log_unknown("Building #{distro.name} for branch '#{local_branch}'")
            first_branch = false
          end

          # Copy files into the preview area.
          [[stylesheet_dir, '*css', branch_config.branch_stylesheet_dir],
           [javascript_dir, '*js',  branch_config.branch_javascript_dir],
           [image_dir,      '*',    branch_config.branch_image_dir]].each do |dgroup|
            src_dir = dgroup[0]
            glob    = dgroup[1]
            tgt_dir = dgroup[2]
            if Dir.exist?(src_dir) and not dir_empty?(src_dir)
              FileUtils.mkdir_p tgt_dir
              FileUtils.cp_r Dir.glob(File.join(src_dir,glob)), tgt_dir
            end
          end

          # Build the navigation structure for this branch / distro
           navigation = branch_topic_map.nav_tree(distro.id)

          # Build the topic files for this branch & distro
          process_topic_entity_list(branch_config,single_page_path,navigation,branch_topic_map.list)
        end

        # In single-page context, we're done.
        if not single_page.nil?
          #exit 200
          return
        end

        # Remove DITAA-generated images
        ditaa_image_files = Find.find(docs_root_dir).select{ |path| not path.nil? and not (path =~ /_preview/ or path =~ /_package/) and (path =~ /.*\.png$/ or path =~ /.*\.png\.cache$/) and not branch_image_files.include?(path) }
        if not ditaa_image_files.empty?
          log_unknown("Removing ditaa-generated files from repo before changing branches.")
          ditaa_image_files.each do |dfile|
            File.unlink(dfile)
          end
        end

        if local_branch == working_branch
          # We're moving away from the working branch, so save off changed files
          git_stash_all
        end
      end

      # Return to the original branch
      git_checkout(working_branch)

      # If necessary, restore temporarily stashed files
      git_apply_and_drop

      log_unknown("All builds completed.")
    end

    def process_topic_entity_list(branch_config,single_page_path,navigation,topic_entity_list,preview_path='')
      # When called from a topic group entity, create the preview dir for that group
      Dir.mkdir(preview_path) unless preview_path == '' or File.exists?(preview_path)

      topic_entity_list.each do |topic_entity|
        # If this topic entity or any potential subentities are outside of the distro or single-page params, skip it.
        next unless topic_entity.include?(branch_config.distro.id,single_page_path)

        if topic_entity.is_group?
          preview_path = topic_entity.preview_path(branch_config.distro.id,branch_config.dir)
          process_topic_entity_list(branch_config,single_page_path,navigation,topic_entity.subitems,preview_path)
        elsif topic_entity.is_topic?
          if topic_entity.is_alias?
            configure_and_generate_alias(topic_entity,branch_config)
          else
            if File.exists?(topic_entity.source_path)
              if single_page_path.length == 0
                log_info("  - #{topic_entity.repo_path}")
              end
              configure_and_generate_page(topic_entity,branch_config,navigation)
            else
              log_warn("  - #{topic_entity.repo_path} <= Skipping nonexistent file")
            end
          end
        end
      end
    end

    def configure_and_generate_alias(topic,branch_config)
      distro       = branch_config.distro
      topic_target = topic.topic_alias
      unless valid_url?(topic_target)
        topic_target = File.join(branch_config.branch_url_base,topic_target + ".html")
      end
      topic_text = alias_text(topic_target)
      preview_path = topic.preview_path(distro.id,branch_config.dir)
      File.write(preview_path,topic_text)
    end

    def configure_and_generate_page(topic,branch_config,navigation)
      distro = branch_config.distro
      # topic_adoc = File.open(topic.source_path,'r').read

      page_attrs = asciidoctor_page_attrs([
        "imagesdir=#{File.join(topic.parent.source_path,'images')}",
        branch_config.distro.id,
        "product-title=#{branch_config.distro_name}",
        "product-version=#{branch_config.name}",
        "product-author=#{branch_config.distro_author}",
        "repo_path=#{topic.repo_path}",
        "allow-uri-read="
      ])

      File.open topic.source_path, 'r' do |topic_file|

        doc = without_warnings { Asciidoctor.load topic_file, :header_footer => false, :safe => :unsafe, :attributes => page_attrs, :base_dir => "." }
        article_title = doc.doctitle || topic.name

        topic_html = doc.render

        # This is logic bridges newer arbitrary-depth-tolerant code to
        # older depth-limited code. Truly removing depth limitations will
        # require changes to page templates in user docs repos.
        breadcrumb     = topic.breadcrumb
        group_title    = breadcrumb[0][:name]
        group_id       = breadcrumb[0][:id]
        topic_title    = breadcrumb[-1][:name]
        topic_id       = breadcrumb[-1][:id]
        subgroup_title = nil
        subgroup_id    = nil
        if breadcrumb.length == 3
          subgroup_title = breadcrumb[1][:name]
          subgroup_id    = breadcrumb[1][:id]
        end
        dir_depth = '../' * topic.breadcrumb[-1][:id].split('::').length
        dir_depth = '' if dir_depth.nil?

        preview_path = topic.preview_path(distro.id,branch_config.dir)
        topic_publish_url = topic.topic_publish_url(distro.site.url,branch_config.dir)

        page_args = {
          :distro_key        => distro.id,
          :distro            => branch_config.distro_name,
          :branch            => branch_config.id,
          :site_name         => distro.site.name,
          :site_url          => distro.site.url,
          :topic_url         => preview_path,
          :topic_publish_url => topic_publish_url,
          :version           => branch_config.name,
          :group_title       => group_title,
          :subgroup_title    => subgroup_title,
          :topic_title       => topic_title,
          :article_title     => article_title,
          :content           => topic_html,
          :navigation        => navigation,
          :group_id          => group_id,
          :subgroup_id       => subgroup_id,
          :topic_id          => topic_id,
          :css_path          => "#{dir_depth}#{branch_config.dir}/#{STYLESHEET_DIRNAME}/",
          :javascripts_path  => "#{dir_depth}#{branch_config.dir}/#{JAVASCRIPT_DIRNAME}/",
          :images_path       => "#{dir_depth}#{branch_config.dir}/#{IMAGE_DIRNAME}/",
          :site_home_path    => "#{dir_depth}index.html",
          :template_path     => template_dir,
          :repo_path         => topic.repo_path,
        }
        full_file_text = page(page_args)


        File.open(preview_path, 'w') { |file| file.write(full_file_text) }


        # File.write(preview_path,full_file_text)

      end
    end

    # package_docs
    # This method generates the docs and then organizes them the way they will be arranged
    # for the production websites.
    def package_docs(package_site)
      site_map.sites.each do |site|
        next if not package_site == '' and not package_site == site.id
        site.distros.each do |distro_id,branches|
          branches.each do |branch|
            src_dir  = File.join(preview_dir,distro_id,branch.dir)
            tgt_tdir = branch.dir.split('/')
            tgt_tdir.pop
            tgt_dir  = ''
            if tgt_tdir.length > 0
              tgt_dir = File.join(package_dir,site.id,tgt_tdir.join('/'))
            else
              tgt_dir = File.join(package_dir,site.id)
            end
            next if not File.directory?(src_dir)
            FileUtils.mkdir_p(tgt_dir)
            FileUtils.cp_r(src_dir,tgt_dir)
          end
          site_dir = File.join(package_dir,site.id)
          if File.directory?(site_dir)
            log_unknown("Packaging #{distro_id} for #{site.id} site.")

            # Any files in the root of the docs repo with names ending in:
            #     *-#{site}.html
            # will get copied into the root dir of the packaged site with
            # the site name stripped out.
            #
            # Example: for site name 'commercial', the files:
            #     * index-commercial.html would end up as #{site_root}/index.html
            #     * search-commercial.html would end up as #{site_root}/search.html
            #     * index-community.html would be ignored
            site_files = Dir.glob(File.join(docs_root_dir, '*-' + site.id + '.html'))
            unless site_files.empty?
              site_files.each do |fpath|
                target_basename = File.basename(fpath).gsub(/-#{site.id}\.html$/, '.html')
                FileUtils.cp(fpath,File.join(package_dir,site.id,target_basename))
              end
            else
              FileUtils.cp(File.join(preview_dir,distro_id,'index.html'),File.join(package_dir,site.id,'index.html'))
            end
            ['_images','_stylesheets'].each do |support_dir|
              FileUtils.cp_r(File.join(docs_root_dir,support_dir),File.join(package_dir,site.id,support_dir))
            end

            # Now build a sitemap
            site_dir_path = Pathname.new(site_dir)
            SitemapGenerator::Sitemap.create(
              :default_host => site.url,
              :public_path  => site_dir_path,
              :compress     => false,
              :filename     => File.join(site_dir,'sitemap')
            ) do
              file_list = Find.find(site_dir).select{ |path| not path.nil? and path =~ /.*\.html$/ }.map{ |path| '/' + Pathname.new(path).relative_path_from(site_dir_path).to_s }
              file_list.each do |file|
                add(file, :changefreq => 'daily')
              end
            end
          end
        end
      end
    end

    def clean_up
      if not system("rm -rf #{docs_root_dir}/_preview/* #{docs_root_dir}/_package/*")
        log_unknown("Nothing to clean.")
      end
    end
  end
end
