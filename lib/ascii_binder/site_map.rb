require 'ascii_binder/site_info'

module AsciiBinder
  class SiteMap
    def initialize(distro_map)
      @site_map = {}
      distro_map.distros.each do |distro|
        unless @site_map.has_key?(distro.site.id)
          @site_map[distro.site.id] = AsciiBinder::SiteInfo.new(distro)
        else
          @site_map[distro.site.id].add_distro(distro)
        end
      end
    end

    def sites
      return @site_map.values
    end

    def ids
      return @site_map.keys
    end
  end
end
