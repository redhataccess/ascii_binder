require 'ascii_binder/helpers'

include AsciiBinder::Helpers

module AsciiBinder
  class DistroBranch
    attr_reader :id, :name, :dir, :distro, :distro_name, :distro_author

    def initialize(branch_name,branch_config,distro)
      @id            = branch_name
      @name          = branch_config['name']
      @dir           = branch_config['dir']
      @distro        = distro
      @distro_name   = distro.name
      @distro_author = distro.author
      if branch_config.has_key?('distro-overrides')
        if branch_config['distro-overrides'].has_key?('name')
          @distro_name = branch_config['distro-overrides']['name']
        end
        if branch_config['distro-overrides'].has_key?('author')
          @distro_author = branch_config['distro-overrides']['author']
        end
      end
    end

    def branch_path
      @branch_path ||= File.join(preview_dir,@distro.id,@dir)
    end

    def branch_url_base
      @branch_url_base ||= File.join('/',@dir)
    end

    def branch_stylesheet_dir
      @branch_stylesheet_dir ||= File.join(branch_path,STYLESHEET_DIRNAME)
    end

    def branch_javascript_dir
      @branch_javascript_dir ||= File.join(branch_path,JAVASCRIPT_DIRNAME)
    end

    def branch_image_dir
      @branch_image_dir ||= File.join(branch_path,IMAGE_DIRNAME)
    end

    def is_valid?
      validate
    end

    def errors
      validate(true)
    end

    private

    def validate(verbose=true)
      errors = []
      unless valid_string?(@id)
        if verbose
          errors << "Branch ID '#{@id}' is not a valid string."
        else
          return false
        end
      end
      unless valid_string?(@name)
        if verbose
          errors << "Branch name '#{@name}' for branch ID '#{@id}' is not a valid string."
        else
          return false
        end
      end
      unless valid_string?(@dir)
        if verbose
          errors << "Branch dir '#{@dir}' for branch ID '#{@id}' is not a valid string."
        else
          return false
        end
      end
      unless valid_string?(@distro_name)
        if verbose
          errors << "Branchwise distro name '#{@distro_name}' for branch ID '#{@id}' is not a valid string."
        else
          return false
        end
      end
      unless valid_string?(@distro_author)
        if verbose
          errors << "Branchwise distro author '#{@distro_author}' for branch ID '#{@id}' is not a valid string."
        else
          return false
        end
      end
      return errors if verbose
      return true
    end
  end
end
