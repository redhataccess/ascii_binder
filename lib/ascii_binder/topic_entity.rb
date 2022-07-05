require 'ascii_binder/helpers'
require 'trollop'

include AsciiBinder::Helpers

module AsciiBinder
  class TopicEntity
    attr_reader :name, :dir, :file, :topic_alias, :distro_keys, :subitems, :raw, :parent, :depth

    def initialize(topic_entity,actual_distro_keys,dir_path='',parent_group=nil,depth=0)
      @raw                = topic_entity
      @parent             = parent_group
      @dir_path           = dir_path
      @name               = topic_entity['Name']
      @dir                = topic_entity['Dir']
      @file               = topic_entity['File']
      @topic_alias        = topic_entity['Alias']
      @depth              = depth
      @actual_distro_keys = actual_distro_keys
      @distro_keys        = topic_entity.has_key?('Distros') ? parse_distros(topic_entity['Distros']) : actual_distro_keys
      @nav_trees          = {}
      @alias_lists        = {}
      @path_lists         = {}
      @subitems           = []
      if topic_entity.has_key?('Topics')
        entity_dir  = @dir.nil? ? '<nil_dir>' : @dir
        subdir_path = dir_path == '' ? entity_dir : File.join(dir_path,entity_dir)
        topic_entity['Topics'].each do |sub_entity|
          @subitems << AsciiBinder::TopicEntity.new(sub_entity,actual_distro_keys,subdir_path,self,depth+1)
        end
      end
    end

    def repo_path
      @repo_path ||= begin
        this_step = '<nil_item>'
        if is_group?
          this_step = dir
        elsif is_topic?
          this_step = file.end_with?('.adoc') ? file : "#{file}.adoc"
        end
        @dir_path == '' ? this_step : File.join(@dir_path,this_step)
      end
    end

    def basename_path
      @basename_path ||= File.join(File.dirname(repo_path),File.basename(repo_path,'.adoc'))
    end

    def repo_path_html
      @repo_path_html ||= is_topic? ? File.join(File.dirname(repo_path),File.basename(repo_path,'.adoc')) + ".html" : repo_path
    end

    def source_path
      @source_path ||= File.join(docs_root_dir,repo_path)
    end

    def preview_path(distro_key,branch_dir)
      File.join(preview_dir,distro_key,branch_dir,repo_path_html)
    end

    def topic_publish_url(distro_url,branch_dir)
      File.join(distro_url,branch_dir,repo_path_html)
    end

    def package_path(site_id,branch_dir)
      File.join(package_dir,site_id,branch_dir,repo_path_html)
    end

    def group_filepaths
      @group_filepaths ||= begin
        group_filepaths = []
        if is_topic? and not is_alias?
          group_filepaths << File.join(File.dirname(repo_path),File.basename(repo_path,'.adoc'))
        elsif is_group?
          subitems.each do |subitem|
            group_filepaths.concat(subitem.group_filepaths)
          end
          group_filepaths.uniq!
        end
        group_filepaths
      end
    end

    def nav_tree(distro_key)
      @nav_trees[distro_key] ||= begin
        nav_tree = {}
        if distro_keys.include?(distro_key) and not is_alias?
          nav_tree[:id]   = id
          nav_tree[:name] = name
          if is_topic?
            nav_tree[:path] = "../" + repo_path_html
          elsif is_group?
            sub_nav_items = []
            subitems.each do |subitem|
              sub_nav = subitem.nav_tree(distro_key)
              next if sub_nav.empty?
              sub_nav_items << sub_nav
            end
            if sub_nav_items.empty?
              nav_tree = {}
            else
              nav_tree[:topics] = sub_nav_items
            end
          end
        end
        nav_tree
      end
    end

    def alias_list(distro_key)
      @alias_lists[distro_key] ||= begin
        sub_aliases = []
        if distro_keys.include?(distro_key)
          if is_group?
            subitems.each do |subitem|
              sub_list = subitem.alias_list(distro_key)
              sub_list.each do |sub_list_alias|
                sub_aliases << sub_list_alias
              end
            end
          elsif is_alias?
            sub_aliases << { :alias_path => basename_path, :redirect_path => topic_alias }
          end
        end
        sub_aliases
      end
    end

    def path_list(distro_key)
      @path_lists[distro_key] ||= begin
        sub_paths = []
        if distro_keys.include?(distro_key)
          if is_group?
            subitems.each do |subitem|
              sub_list = subitem.path_list(distro_key)
              sub_list.each do |sub_list_path|
                sub_paths << sub_list_path
              end
            end
          elsif is_topic? and not is_alias?
            sub_paths << basename_path
          end
        end
        sub_paths
      end
    end

    # Is this topic entity or any of its children used in
    # the specified distro / single page chain
    def include?(distro_key,single_page_path)
      # If this entity isn't for this distro, bail out
      return false unless distro_keys.include?(distro_key)

      # If we're building a single page, check if we're on the right track.
      if single_page_path.length > 0  and not single_page_path[depth].nil?
        if is_group?
          return false unless single_page_path[depth] == dir
        elsif is_topic?
          return false unless single_page_path[depth] == file
        else
          return false
        end
      elsif is_group?
        # If this is a topic group that -is- okay for this distro, but
        # none of its subitems are okay for this distro, then bail out.
        subitems_for_distro = false
        subitems.each do |subitem|
          if subitem.include?(distro_key,[])
            subitems_for_distro = true
            break
          end
        end
        return false unless subitems_for_distro
      end

      return true
    end

    def breadcrumb
      @breadcrumb ||= hierarchy.map{ |entity| { :id => entity.id, :name => entity.name, :url => entity.repo_path_html } }
    end

    def id
      @id ||= hierarchy.map{ |entity| camelize(entity.name) }.join('::')
    end

    def is_group?
      @is_group ||= file.nil? and not name.nil? and not dir.nil? and subitems.length > 0
    end

    def is_topic?
      @is_topic ||= dir.nil? and not name.nil? and not file.nil? and subitems.length == 0
    end

    def is_alias?
      @is_alias ||= is_topic? and not topic_alias.nil?
    end

    def is_valid?
      validate
    end

    def errors
      validate(true)
    end

    private

    def parse_distros(entity_distros)
      values = entity_distros.split(',').map(&:strip)
      # Don't bother with glob expansion if 'all' is in the list.
      return @actual_distro_keys if values.include?('all')

      # Expand globs and return the list
      values.flat_map do |value|
        value_regex = Regexp.new("\\A#{value.gsub("*", ".*")}\\z")
        @actual_distro_keys.select { |k| value_regex.match(k) }
      end.uniq
    end

    def validate(verbose=false)
      errors = []

      # Check common fields - Name and Distros
      if not valid_string?(name)
        if verbose
          errors << "Topic entity with missing or invalid 'Name' value: '#{raw.inspect}'"
        else
          return false
        end
      end
      distro_keys.each do |distro_key|
        next if @actual_distro_keys.include?(distro_key)
        if verbose
          errors << "#{entity_id} 'Distros' filter includes nonexistent distro key '#{distro_key}'"
        else
          return false
        end
      end

      # Check the depth.
      if (depth > AsciiBinder::DEPTH) and (AsciiBinder::DEPTH != 0)
        if verbose
          errors << "#{entity_id} exceeds the maximum nested depth."
        else
          return false
        end
      end

      # For groups, test the 'Dir' value and the sub-items.
      if is_group?
        if not valid_string?(dir)
          if verbose
            errors << "#{entity_id} has invalid 'Dir' value."
          else
            return false
          end
        end
        if not topic_alias.nil?
          if verbose
            errors << "#{entity_id} is a topic group with an Alias entry. Aliases are only supported for topic items."
          else
            return false
          end
        end
        subitems.each do |subitem|
          next if subitem.is_valid?
          if verbose
            errors = errors.concat(subitem.errors)
          else
            return false
          end
        end
      elsif is_topic?
        if not valid_string?(file)
          if verbose
            errors << "#{entity_id} has invalid 'File' value."
          else
            return false
          end
        end
        # We can do basic validation of the 'Alias' string here, but real validation has
        # to be done after the whole topic map is loaded.
        if not topic_alias.nil? and not valid_string?(topic_alias)
          if verbose
            errors << "#{entity_id} has invalid 'Alias' value."
          else
            return false
          end
        end
      else
        if verbose
          errors << "#{entity_id} is not parseable as a group or a topic: '#{raw.inspect}'"
        else
          return false
        end
      end
      return errors if verbose
      return true
    end

    def hierarchy
      @hierarchy ||= begin
        entity   = self
        ancestry = []
        loop do
          ancestry << entity
          break if entity.parent.nil?
          entity = entity.parent
        end
        ancestry.reverse
      end
    end

    def entity_id
      if hierarchy.length == 1
        return "Top level topic entity '#{name}'"
      else
        return "Topic entity at '#{breadcrumb.map{ |node| node[:name] }.join(' -> ')}'"
      end
    end
  end
end
