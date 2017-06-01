require 'ascii_binder/distro_branch'
require 'ascii_binder/helpers'
require 'ascii_binder/site'
require 'trollop'

include AsciiBinder::Helpers

module AsciiBinder
  class Distro
    attr_reader :id, :name, :author, :site

    def initialize(distro_map_filepath,distro_key,distro_config)
      @id         = distro_key
      @name       = distro_config['name']
      @author     = distro_config['author']
      @site       = AsciiBinder::Site.new(distro_config)
      @branch_map = {}
      distro_config['branches'].each do |branch_name,branch_config|
        if @branch_map.has_key?(branch_name)
          Trollop::die "Error parsing #{distro_map_filepath}: distro '#{distro_key}' lists git branch '#{branch_name}' multiple times."
        end
        @branch_map[branch_name] = AsciiBinder::DistroBranch.new(branch_name,branch_config,self)
      end
    end

    def is_valid?
      validate
    end

    def errors
      validate(true)
    end

    def branch(branch_name)
      unless @branch_map.has_key?(branch_name)
        Trollop::die "Distro '#{@id}' does not include branch '#{branch_name}' in the distro map."
      end
      @branch_map[branch_name]
    end

    def branch_ids
      @branch_map.keys
    end

    def branches
      @branch_map.values
    end

    private

    def validate(verbose=false)
      errors = []
      unless valid_id?(@id)
        if verbose
          errors << "Distro ID '#{@id}' is not a valid string"
        else
          return false
        end
      end
      unless valid_string?(@name)
        if verbose
          errors << "Distro name '#{@name}' for distro '#{@id}' is not a valid string."
        else
          return false
        end
      end
      unless valid_string?(@author)
        if verbose
          errors << "Distro author '#{@author}' for distro '#{@id}' is not a valid string."
        else
          return false
        end
      end

      # Remaining checks are sub objects. Handle the verbose case first.
      if verbose
        site_errors = @site.errors
        unless site_errors.empty?
          error_txt = "The site info has errors:\n"
          site_errors.each do |error|
            error_txt << "    * #{error}\n"
          end
          errors << error_txt
        end
        all_branch_errors = []
        @branch_map.values.each do |branch|
          branch_errors = branch.errors
          unless branch_errors.empty?
            all_branch_errors << "    * In branch #{branch.id}:\n"
            branch_errors.each do |error|
              all_branch_errors << "        * #{error}\n"
            end
          end
        end
        unless all_branch_errors.empty?
          all_branch_errors.unshift("The branch info has errors:")
          errors.concat(all_branch_errors)
        end
        return errors
      end

      # Still here? Run the non-verbose checks instead.
      return false unless @site.is_valid?
      @branch_map.values.each do |branch|
        return false unless branch.is_valid?
      end

      return true
    end
  end
end
