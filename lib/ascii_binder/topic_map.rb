require 'ascii_binder/helpers'
require 'ascii_binder/topic_entity'
require 'trollop'
require 'yaml'

include AsciiBinder::Helpers

module AsciiBinder
  class TopicMap
    attr_reader :list

    def initialize(topic_file,distro_keys)
      @topic_yaml = YAML.load_stream(open(File.join(source_dir,topic_file)))
      @list       = []
      @topic_yaml.each do |topic_entity|
        @list << AsciiBinder::TopicEntity.new(topic_entity,distro_keys)
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
        next if entity_nav.nil?
        nav_tree << entity_nav
      end
      return nav_tree
    end

    def is_valid?
      @list.each do |topic_entity|
        next if topic_entity.is_valid? and topic_entity.is_group?
        return false
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
      return errors
    end
  end
end
