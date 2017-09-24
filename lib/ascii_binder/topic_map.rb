require 'ascii_binder/helpers'
require 'ascii_binder/topic_entity'
require 'trollop'
require 'yaml'

include AsciiBinder::Helpers

module AsciiBinder
  class TopicMap
    attr_reader :list

    def initialize(topic_file,distro_keys)
      @topic_yaml  = YAML.load_stream(open(File.join(docs_root_dir,topic_file)))
      @distro_keys = distro_keys
      @list        = []
      @topic_yaml.each do |topic_entity|
        @list << AsciiBinder::TopicEntity.new(topic_entity,distro_keys)
      end
    end

    def dirpaths
      @dirpaths ||= begin
        dirpaths = []
        @list.each do |topic_entity|
          dirpaths.concat(topic_entity.group_dirpaths)
        end
        dirpaths
      end
    end

    def filepaths
      @filepaths ||= begin
        filepaths = []
        @list.each do |topic_entity|
          filepaths.concat(topic_entity.group_filepaths)
        end
        filepaths
      end
    end

    def nav_tree(distro_key)
      nav_tree = []
      @list.each do |topic_entity|
        entity_nav = topic_entity.nav_tree(distro_key)
        next if entity_nav.empty?
        nav_tree << entity_nav
      end
      return nav_tree
    end

    def alias_list(distro_key)
      alias_list = []
      @list.each do |topic_entity|
        alias_sublist = topic_entity.alias_list(distro_key)
        next if alias_sublist.empty?
        alias_list.push(*alias_sublist)
      end
      return alias_list
    end

    def path_list(distro_key)
      path_list = []
      @list.each do |topic_entity|
        path_sublist = topic_entity.path_list(distro_key)
        next if path_sublist.empty?
        path_list.push(*path_sublist)
      end
      return path_list
    end

    def is_valid?
      @list.each do |topic_entity|
        next if topic_entity.is_valid? and topic_entity.is_group?
        return false
      end
      # Test all aliases
      @distro_keys.each do |distro_key|
        distro_aliases = alias_list(distro_key)
        distro_paths   = path_list(distro_key)
        distro_aliases.each do |alias_map|
          return false if distro_paths.include?(alias_map[:alias_path])
          next if valid_url?(alias_map[:redirect_path])
          return false unless distro_paths.include?(alias_map[:redirect_path])
        end
      end
      return true
    end

    def errors
      errors = []
      @list.each do |topic_entity|
        if not topic_entity.is_group?
          errors << "Top-level entries in the topic map must all be topic groups. Entity with name '#{topic_entity.name}' is not a group."
          next
        end
        next if topic_entity.is_valid?
        errors << topic_entity.errors
      end
      # Test all aliases
      @distro_keys.each do |distro_key|
        distro_aliases = alias_list(distro_key)
        distro_paths   = path_list(distro_key)
        distro_aliases.each do |alias_map|
          if distro_paths.include?(alias_map[:alias_path])
            errors << "An actual topic file and a topic alias both exist at the same path '#{alias_map[:alias_path]}' for distro '#{distro_key}'"
          end
          next if valid_url?(alias_map[:redirect_path])
          if not distro_paths.include?(alias_map[:redirect_path])
            errors << "Topic alias '#{alias_map[:alias_path]}' points to a nonexistent topic '#{alias_map[:redirect_path]}' for distro '#{distro_key}'"
          end
        end
      end
      return errors
    end

    private

    def validate_alias(topic_entity)
    end
  end
end
