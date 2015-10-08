require 'tilt'

module AsciiBinder
  class TemplateRenderer
    attr_reader :source_dir, :template_cache

    def initialize(source_dir,template_directory)
      @source_dir = source_dir
      @template_cache = {}
      Dir.glob(File.join(template_directory, "**/*")).each do |file|
        @template_cache[file] = Tilt.new(file, :trim => "-")
      end
    end

    def render(template, args = {})
      # Inside erb files, template path is local to repo
      if not template.start_with?(source_dir)
        template = File.join(source_dir, template)
      end
      renderer_for(template).render(self, args).chomp
    end

    private

    def renderer_for(template)
      template_cache.fetch(File.expand_path(template))
    end
  end
end
