require 'ascii_binder/distro'
require 'trollop'
require 'yaml'

module AsciiBinder
  class DistroMap
    def initialize(distro_map_filepath)
      @distro_yaml = YAML.load_file(distro_map_filepath)
      @distro_map  = {}
      @distro_yaml.each do |distro_key,distro_config|
        if @distro_map.has_key?(distro_key)
          Trollop::die "Error parsing '#{distro_map_filepath}': distro key '#{distro_key}' is used more than once."
        end
        distro = AsciiBinder::Distro.new(distro_map_filepath,distro_key,distro_config)
        @distro_map[distro_key] = distro
      end
    end

    def get_distro(distro_key)
      unless @distro_map.has_key?(distro_key)
        Trollop::die "Distro key '#{distro_key}' does not exist"
      end
      @distro_map[distro_key]
    end

    def include_distro_key?(distro_key)
      @distro_map.has_key?(distro_key)
    end

    def distro_keys
      @distro_map.keys
    end

    def distros
      @distro_map.values
    end

    def distro_branches(distro_key='')
      if distro_key == ''
        branch_list = []
        distros.each do |distro|
          branch_list.concat(distro.branch_ids)
        end
        return branch_list.uniq
      else
        return get_distro(distro_key).branch_ids
      end
    end

    def is_valid?
      @distro_map.values.each do |distro|
        next if distro.is_valid?
        return false
      end
      return true
    end

    def errors
      errors = []
      @distro_map.values.each do |distro|
        next if distro.is_valid?
        errors << distro.errors
      end
      return errors
    end
  end
end
