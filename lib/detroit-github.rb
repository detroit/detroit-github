require 'detroit/tool'

module Detroit

  # Convenience method for creating a GitHub tool instance.
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

    #
    PAGES_BRANCH = "gh-pages"

    #
    DEFAULT_FOLDER = "pages"

    #
    DEFAULT_REMOTE = "origin"

    #
    DEFAULT_MESSAGE ="Update by Detroit. [admin]"


    #  A T T R I B U T E S

    # The remote to use (defaults to 'origin').
    attr_accessor :remote

    # Commit message.
    attr_accessor :message

    # Pages folder to use (defaults to 'pages').
    attr_accessor :folder

    #
    alias_accessor :gh_pages, :folder

    # Use a local check out?
    #attr_accessor :local

    # List of directories and files to transfer.
    # If a single directory entry is given then the contents
    # of that directory will be transfered.
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

    #  A S S E M B L Y

    # Do not need to `prepare` if gh_pages directory is already created.
    def assemble?(station, options={})
      case station
      when :prepare
        child ? false : true
      when :publish, :clean
        true
      end
    end

    # Attach to `prepare`, `publish` and `clean`.
    def assemble(station, options={})
      case station
      when :prepare then prepare
      when :publish then publish
      when :clean   then clean
      end
    end

    #  S E R V I C E   M E T H O D S 

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

    # Publish sitemap files to branch (gh-pages).
    def publish
      if !File.directory?(pgdir)
        report "No pages folder found (#{folder})."
        return
      end

      chdir(pgdir) do
        sh %[git push #{remote} #{branch}]
      end

      #paths_to_remove.each do |path|
      #  path = File.join(tmpdir, path)
      #  rm path if File.file?(path)
      #end

      #expanded_sitemap.each do |(src, dest)|
      #  trace "transfer: #{src} => #{dest}"
      #  if directory?(src)
      #    out = File.join(tmpdir, dest)
      #    mkdir_p(out) unless File.directory?(out)
      #  else
      #    out = File.join(tmpdir, dest)
      #    mkdir_p(File.dirname(out))
      #    install(src, out) unless keep.include?(dest)
      #  end
      #end

      #chdir(tmpdir) do
      #  sh %[git add --all]
      #  sh %[git commit -q -a -m "#{message}"]
      #  sh %[git push #{remote} #{branch}]  # TODO: add --dry-run if trial?
      #  sh %[git push #{url} #{branch}]     # TODO: add --dry-run if trial?
      #end
    end

    #
    def clean
      rm_r File.join(Dir.tmpdir, 'detroit', 'github')
    end

  private

    # Clone the repo to a local folder, checkout the pages
    # branch and remove the master branch.
    #
    # NOTE: Considered using `sh %[git clone --local . #{pgdir}]` but
    # that appeared to require duplicate commits, once in pgdir and
    # then in root.
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

    # TODO: Does the POM Project provide the site folder?

    #
    def initialize_defaults
      @branch   ||= PAGES_BRANCH
      @folder   ||= DEFAULT_FOLDER
      @remote   ||= DEFAULT_REMOTE
      @message  ||= DEFAULT_MESSAGE
    end

    # Require Grit.
    #
    # TODO: Switch to `scm` gem if it is better than grit.
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

=begin
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

  public

    def self.man_page
      File.dirname(__FILE__)+'/../man/detroit-github.5'
    end

  end

end
