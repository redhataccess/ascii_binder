
require 'ascii_binder/helpers'
require 'trollop'

include AsciiBinder::Helpers

module AsciiBinder
  class TopicAlias
    def initialize(preview_dir,distro_key,branch_dir,target_url,alias_url)
      @target_url  = target_url
      @branch_dir  = branch_dir
      @distro_key  = distro_key
      @preview_dir = preview_dir
      @alias_path  = alias_url.split('/')
      @alias_name  = @alias_path.pop
    end

    def preview_path
      @preview_path ||= File.join(@preview_dir,@distro_key,@branch_dir,@alias_path)
    end

    def filepath
      File.join(preview_path,File.basename(@alias_name,".*") + ".html")
    end

    def file_text
      "<!DOCTYPE html><html><head><title>#{@target_url}</title><link rel=\"canonical\" href=\"#{@target_url}\"/><meta name=\"robots\" content=\"noindex\"><meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" /><meta http-equiv=\"refresh\" content=\"0; url=#{@target_url}\" /></head></html>"
    end
  end
end
