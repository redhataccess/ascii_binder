module AsciiBinder
  class SiteInfo
    attr_reader :id, :name, :url, :distros, :branches

    def initialize(distro)
      @id       = distro.site.id
      @name     = distro.site.name
      @url      = distro.site.url
      @distros  = {}
      @branches = ['master']
      add_distro(distro)
    end

    def add_distro(distro)
      @distros[distro.id] = distro.branches
      distro.branches.each do |branch|
        next if @branches.include?(branch.id)
        @branches << branch.id
      end
    end
  end
end
