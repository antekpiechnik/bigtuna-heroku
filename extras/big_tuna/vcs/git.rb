module BigTuna::VCS
  class Git < Base
    NAME = "Git"
    VALUE = "git"

    def self.supported?
      return @_supported unless @_supported.nil?
      begin
        @_supported = BigTuna::Runner.execute(Dir.pwd, "git --version").ok?
      rescue BigTuna::Runner::Error => e
        @_supported = false
      end
      @_supported
    end

    def head_info
      info = {}
      command = "git log --max-count=1 --pretty=format:\"%H%n%an%n%ae%n%ad%n%s\" #{self.branch}"
      begin
        output = BigTuna::Runner.execute(self.source, command)
      rescue BigTuna::Runner::Error => e
        raise BigTuna::VCS::Error.new(e.backtrace.join("\n"))
      end
      head_hash = output.stdout
      info[:commit] = head_hash.shift
      info[:author] = head_hash.shift
      info[:email] = head_hash.shift
      info[:committed_at] = Time.parse(head_hash.shift)
      info[:commit_message] = head_hash.join("\n")
      [info, command]
    end

    def clone(where_to)
      command = "git clone --depth 1 #{self.source} #{where_to} && cd #{where_to} && git checkout -b #{self.branch} && git pull origin #{self.branch} && cd #{Rails.root}"
      BigTuna::Runner.execute(Dir.pwd, command)
    end
  end
end
