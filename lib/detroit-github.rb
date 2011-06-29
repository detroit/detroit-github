module Detroit

  #
  def GitHub(options={})
    GitHub.new(options)
  end

  # GitHub tool provides services for working with your
  # project's github repository.
  #
  # Currently it only supports gh-pages publishing.
  #
  # IMPORTNAT: This tool is useless unless your project is hosted on GitHub!
  class GitHub < Tool

    # The remote to use (defaults to 'origin').
    attr_accessor :remote

    # The repository branch (defaults to "gh-pages").
    attr_accessor :branch

    # Commit message.
    attr_accessor :message

    # List of directories and files to transfer.
    # If a single directory entry is given then the contents
    # of that directory will be transfered.
    attr_reader :sitemap

    # List of any files/directory to not overwrite in branch.
    attr_reader :keep

    #
    def sitemap=(entries)
      case entries
      when Array
        @sitemap = entries
      else
        @sitemap = [entries.to_str]
      end
    end

    #
    def keep=(entries)
      case entries
      when Array
        @keep = entries
      else
        @keep = [entries.to_str]
      end
    end

    #
    def publish
      if expanded_sitemap.empty?
        report "No files selected for publishing."
        return
      end

      url = repo.config["remote.#{remote}.url"]
      dir = Dir.pwd  # project.root

      chdir(tmpdir) do
        sh %[git clone --local #{dir} .]
        sh %[git checkout #{branch}]
      end

      paths_to_remove.each do |path|
        path = File.join(tmpdir, path)
        rm path if File.file?(path)
      end

      expanded_sitemap.each do |(src, dest)|
        trace "transfer: #{src} => #{dest}"
        if directory?(src)
          out = File.join(tmpdir, dest)
          mkdir_p(out) unless File.directory?(out)
        else
          out = File.join(tmpdir, dest)
          mkdir_p(File.dirname(out))
          install(src, out) unless keep.include?(dest)
        end
      end

      chdir(tmpdir) do
        sh %[git add --all]
        sh %[git commit -a -m "#{message}"]
        sh %[git push -q #{url} #{branch}]  # TODO: add --dry-run if trial?
      end
    end

  private

    # TODO: Does the POM Project provide the site directory?
    def initialize_defaults
      @branch   ||= 'gh-pages'
      @remote   ||= 'origin'
      @message  ||= 'Update website via Detroit.'
      @sitemap  ||= default_sitemap
      @keep     ||= []
    end

    #
    def initialize_requires
      require 'grit'
    end

    #
    def repo
      @repo ||= Grit::Repo.new(project.root)
    end

    #
    def tmpdir
      @tmpdir ||= (
        tmpdir = File.join(Dir.tmpdir, 'detroit', 'github', Time.now.to_i.to_s)
        mkdir_p(tmpdir)
      )
    end

    # Default sitemap includes the `site` directoy, if it exists.
    # Otherwise the `doc` directory.
    def default_sitemap
      sm = []
      if dir = Dir['{site,web,website,www}'].first
        sm << dir
      elsif dir = Dir["{doc,docs}"].first
        sm << dir
      end
      sm
    end

    # Exapnd the sitemap such that every source path to be copied
    # from the site directory is mapped to it's corresponding destination.
    def expanded_sitemap
      @expanded_sitemap ||= (
        fullmap = []
        sitemap.each do |(src, dest)|
          dest = '.' if dest.nil?
          if directory?(src)
            chdir(src) do
              Dir['**/*'].each do |s|
                fullmap << [File.join(src, s), File.join(dest, s).sub(/^\.\//,'')]
              end
            end
          else
            fullmap << [src, dest]
          end
        end
        fullmap
      )
    end

    #
    def paths_to_remove
      present = []
      arrival = expanded_sitemap.map{ |(s,d)| d }
      chdir tmpdir do
        present = Dir['**/*']
      end
      paths = arrival - present - keep
      paths
    end

  end

end
