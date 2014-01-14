require 'detroit-standard'

module Detroit

  # FIXME: Sitemap feature is out-of-order!

  ##
  # GitHub tool provides services for working with your
  # project's github repository.
  #
  # Currently it only supports gh-pages publishing.
  #
  # The following stations of the standard toolchain are targeted:
  #
  # * prepare
  # * publish
  # * clean
  #
  # @note This tool is useless unless your project is hosted on GitHub!
  class GitHub < Tool

    # Works with the Standard assembly.
    #
    # @!parse
    #   include Standard
    #
    assembly Standard

    # Location of manpage for tool.
    MANPAGE = File.dirname(__FILE__)+'/../man/detroit-github.5'

    #
    PAGES_BRANCH = "gh-pages"

    # The project directory to store the gh-pages git repo.
    DEFAULT_FOLDER = "web"

    # Default remote name.
    DEFAULT_REMOTE = "origin"

    # Default commit message.
    DEFAULT_MESSAGE = "Update pages via Detroit."

    #
    def prerequisite
      @branch  = PAGES_BRANCH
      @folder  = DEFAULT_FOLDER
      @remote  = DEFAULT_REMOTE
      @message = DEFAULT_MESSAGE
    end

    # The remote to use (defaults to 'origin').
    attr_accessor :remote

    # Commit message.
    attr_accessor :message

    # Pages folder to use (defaults to 'pages').
    attr_accessor :folder

    # Alias for `#folder`.
    alias_accessor :gh_pages, :folder

    # Use a local check out?
    #attr_accessor :local

    # List of directories and files to copy to pages.
    # If a single directory entry is given then the contents
    # of that directory will be copied.
    #attr_reader :sitemap

    # List of any files/directory to not overwrite in branch.
    #attr_reader :keep

    # Set sitemap.
    def sitemap=(entries)
      case entries
      when String
        @sitemap = [entries.to_str]
      else
        @sitemap = entries
      end
    end

    # Set keep list.
    def keep=(entries)
      case entries
      when String
        @keep = [entries.to_str]
      else
        @keep = entries
      end
    end

    # The repository branch (ALWAYS "gh-pages").
    attr_reader :branch

    #
    def prepare
      return if child

      if File.exist?(pgdir)
        abort "Can't setup gh-pages at #{folder}. Directory already exists."
      end

      # does the master repo have a gh-pages branch?
      new = !master.branches.find{ |b| b.name == branch }

      if new
        create_branch
      else
        clone_branch
      end

      update_gitignore
    end

    # We do not need to prepare if gh_pages directory is already created.
    def prepare?
      !child
    end

    # Publish sitemap files to branch (gh-pages).
    #
    # @todo Should we `git add --all` ?
    #
    # @return [void]
    def publish
      if !File.directory?(pgdir)
        report "No pages folder found (#{folder})."
        return
      end

      #copy_files  # post_generate assembly ?

      chdir(pgdir) do
        #sh %[git add -A]
        sh %[git commit -q -a -m "#{message}"]
        sh %[git push #{remote} #{branch}]
      end
    end

    # Remove temporary directory.
    def clean
      rm_r File.join(Dir.tmpdir, 'detroit', 'github')
    end

    # @method :station_publish(opts = {})
    station :prepare

    # @method :station_publish(opts = {})
    station :publish

    # @method :station_clean(opts = {})
    station :clean

    # This tool ties into the `prepare`, `publish` and `clean` stations of the
    # standard assembly.
    #
    # @return [Boolean]
    def assemble?(station, options={})
      return true if station == :prepare
      return true if station == :publish
      return true if station == :purge
      return false
    end

  private

    # NOTE: Considered using `sh %[git clone --local . #{pgdir}]` but
    # that appeared to require duplicate commits, once in pgdir and
    # then in root.

    # Clone the repo to a local folder, checkout the pages
    # branch and remove the master branch.
    #
    def clone_branch
      sh %[git clone #{url} #{pgdir}]
      Dir.chdir(pgdir) do
        sh %[git checkout #{branch}]
        sh %[git branch -d master]
      end
    end

    # TODO: This assumes we started out on master. Look up current and swtich back to that.

    # If the gh-pages branch doesn't exist we need to create it.
    def create_branch
      sh %[git clone #{url} #{pgdir}]
      Dir.chdir(pgdir) do
        sh %[git symbolic-ref HEAD refs/heads/#{branch}]
        sh %[rm .git/index]
        sh %[git clean -fdxq]
        sh %[echo "My GitHub Page" > index.html]
        sh %[git add .]
        sh %[git commit -a -m "First pages commit."]
        sh %[git push origin #{branch}]
        sh %[git checkout #{branch}]
        sh %[git branch -d master]
      end
    end

    # Only updates .gitignore if folder is not already present.
    def update_gitignore
      file = File.join(root, '.gitignore')
      if File.exist?(file)
        done = false
        File.readlines(file).each do |line|
          done = true if line.strip == folder
        end
        append(file, folder) unless done
      else
        write(file, folder)
      end
    end

    # TODO: Does the Project provide the site folder?

    # TODO: Switch to `scm` gem if it is better than grit.

    # Require Grit.
    def initialize_requires
      require 'grit'
    end

    # Get a cached Grit::Repo instance.
    def master
      @master ||= Grit::Repo.new(root)
    end

    # Remote URL for master.
    def url
      @url ||= master.config["remote.#{remote}.url"]
    end

    # Child Grit::Repo instance, i.e. a repo just for gh-pages.
    def child
      @child ||= \
        begin
          Grit::Repo.new(pgdir) if File.directory?(pgdir)
        rescue Grit::InvalidGitRepositoryError
          nil          
        end
    end

    # Location of child folder.
    def pgdir
      @pgdir ||= File.join(root,folder)
    end

    # Cached system temporary directory.
    def tmpdir
      @tmpdir ||= (
        tmpdir = File.join(Dir.tmpdir, 'detroit', 'github', Time.now.to_i.to_s)
        mkdir_p(tmpdir)
        tmpdir
      )
    end

    #
    def root
      project ? project.root : Dir.pwd
    end

    # TODO: Add support to copy files from project root to gh-pages folder.
    #       This can be helpful when serving generated content.

=begin
    # Copy files from project root to gh-pages folder.
    def copy_files
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
=end

  end

end
