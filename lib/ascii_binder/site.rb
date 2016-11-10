require 'ascii_binder/helpers'

include AsciiBinder::Helpers

module AsciiBinder
  class Site
    attr_reader :id, :name, :url

    def initialize(distro_config)
      @id   = distro_config['site']
      @name = distro_config['site_name']
      @url  = distro_config['site_url']
    end

    def is_valid?
      validate
    end

    def errors
      validate(true)
    end

    private

    def validate(verbose=false)
      errors = []
      unless valid_id?(@id)
        if verbose
          errors << "Site ID '#{@id}' is not a valid ID."
        else
          return false
        end
      end
      unless valid_string?(@name)
        if verbose
          errors << "Site name '#{@name}' for site ID '#{@id}' is not a valid string."
        else
          return false
        end
      end
      unless valid_string?(@url)
        if verbose
          errors << "Site URL '#{@url}' for site ID '#{@id}' is not a valid string."
        else
          return false
        end
      end
      return errors if verbose
      return true
    end
  end
end
