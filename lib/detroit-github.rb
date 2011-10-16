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
    DEFAULT_REMOTE = "origin"

    #
    DEFAULT_MESSAGE ="Update by Detroit. [admin]"


    #  A T T R I B U T E S

    # The remote to use (defaults to 'origin').
    attr_accessor :remote

    # Commit message.
    attr_accessor :message

    # List of directories and files to transfer.
    # If a single directory entry is given then the contents
    # of that directory will be transfered.
    attr_reader :sitemap

    # List of any files/directory to not overwrite in branch.
    attr_reader :keep

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


    #  A S S E M B L Y   S T A T I O N S

    #
    def station_publish
      publish
    end

    #
    def station_clean
      clean
    end


    #  S E R V I C E   M E T H O D S 

    # Publish sitemap files to branch (gh-pages).
    def publish
      if expanded_sitemap.empty?
        report "No files selected for publishing."
        return
      end

      url = repo.config["remote.#{remote}.url"]
      dir = Dir.pwd  # project.root
      new = !repo.branches.find{ |b| b.name == branch }

      create_branch if new

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
        sh %[git commit -q -a -m "#{message}"]
        sh %[git push #{remote} #{branch}]  # TODO: add --dry-run if trial?
        sh %[git push #{url} #{branch}]     # TODO: add --dry-run if trial?
      end
    end

    #
    def clean
      rm_r File.join(Dir.tmpdir, 'detroit', 'github')
    end

  private

    # If the gh-pages branch doesn't exist we will need to create it.
    #--
    # TODO: This assumes we started out on master. Look up current and swtich back to that.
    #++
    def create_branch
      size = repo.status.changed.size +
             repo.status.added.size   +
             repo.status.deleted.size
      if size > 0
        abort "Cannot create gh-pages branch in dirty repo."
      end
      ## save any outstadning changes
      sh 'git stash save'
      ## yes, only a (git) fanboy could possibly think this  
      ## is a good way to handle websites
      sh 'git symbolic-ref HEAD refs/heads/gh-pages'
      sh 'rm .git/index'
      sh 'git clean -fdxq'
      sh 'echo "My GitHub Page" > index.html'
      sh 'git add .'
      sh 'git commit -a -m "First pages commit"'
      sh 'git push origin gh-pages'
      ## gh-pages is made, let's get back to master
      sh 'git checkout master'
      sh 'git stash pop'
    end

    #--
    # TODO: Does the POM Project provide the site directory?
    #++
    def initialize_defaults
      @branch   ||= PAGES_BRANCH
      @remote   ||= DEFAULT_REMOTE
      @message  ||= DEFAULT_MESSAGE
      @sitemap  ||= default_sitemap
      @keep     ||= []
    end

    # Require Grit.
    #
    # TODO: Switch to `scm` gem if it is better than grit.
    def initialize_requires
      require 'grit'
    end

    # Get a cached Grit::Repo instance.
    def repo
      @repo ||= Grit::Repo.new(project ? project.root : Dir.pwd)
    end

    # Cached system temporary directory.
    def tmpdir
      @tmpdir ||= (
        tmpdir = File.join(Dir.tmpdir, 'detroit', 'github', Time.now.to_i.to_s)
        mkdir_p(tmpdir)
        tmpdir
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
