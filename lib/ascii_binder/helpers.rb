module AsciiBinder
  module Helpers
    BUILD_FILENAME      = '_build_cfg.yml'
    TOPIC_MAP_FILENAME  = '_topic_map.yml'
    DISTRO_MAP_FILENAME = '_distro_map.yml'
    PREVIEW_DIRNAME     = '_preview'
    PACKAGE_DIRNAME     = '_package'
    STYLESHEET_DIRNAME  = '_stylesheets'
    JAVASCRIPT_DIRNAME  = '_javascripts'
    IMAGE_DIRNAME       = '_images'
    BLANK_STRING_RE     = Regexp.new('^\s*$')
    ID_STRING_RE        = Regexp.new('^[A-Za-z0-9\-\_]+$')
    URL_STRING_RE       = Regexp.new('^https?:\/\/[\S]+$')

    def valid_id?(check_id)
      return false unless check_id.is_a?(String)
      return false unless check_id.match ID_STRING_RE
      return true
    end

    def valid_string?(check_string)
      return false unless check_string.is_a?(String)
      return false unless check_string.length > 0
      return false if check_string.match BLANK_STRING_RE
      return true
    end

    def valid_url?(check_string)
      return false unless valid_string?(check_string)
      return false unless check_string.match URL_STRING_RE
      return true
    end

    def camelize(text)
      text.gsub(/[^0-9a-zA-Z ]/i, '').split(' ').map{ |t| t.capitalize }.join
    end

    def git_root_dir
      @git_root_dir ||= `git rev-parse --show-toplevel`.chomp
    end

    def gem_root_dir
      @gem_root_dir ||= File.expand_path("../../../", __FILE__)
    end

    def set_docs_root_dir(docs_root_dir)
      AsciiBinder.const_set("DOCS_ROOT_DIR", docs_root_dir)
    end

    def docs_root_dir
      AsciiBinder::DOCS_ROOT_DIR
    end

    def template_renderer
      @template_renderer ||= TemplateRenderer.new(docs_root_dir, template_dir)
    end

    def template_dir
      @template_dir ||= File.join(docs_root_dir,'_templates')
    end

    def preview_dir
      @preview_dir ||= begin
        lpreview_dir = File.join(docs_root_dir,PREVIEW_DIRNAME)
        if not File.exists?(lpreview_dir)
          Dir.mkdir(lpreview_dir)
        end
        lpreview_dir
      end
    end

    def package_dir
      @package_dir ||= begin
        lpackage_dir = File.join(docs_root_dir,PACKAGE_DIRNAME)
        if not File.exists?(lpackage_dir)
          Dir.mkdir(lpackage_dir)
        end
        lpackage_dir
      end
    end

    def stylesheet_dir
      @stylesheet_dir ||= File.join(docs_root_dir,STYLESHEET_DIRNAME)
    end

    def javascript_dir
      @javascript_dir ||= File.join(docs_root_dir,JAVASCRIPT_DIRNAME)
    end

    def image_dir
      @image_dir ||= File.join(docs_root_dir,IMAGE_DIRNAME)
    end

    def alias_text(target)
      "<!DOCTYPE html><html><head><title>#{target}</title><link rel=\"canonical\" href=\"#{target}\"/><meta name=\"robots\" content=\"noindex\"><meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" /><meta http-equiv=\"refresh\" content=\"0; url=#{target}\" /></head></html>"
    end
  end
end
