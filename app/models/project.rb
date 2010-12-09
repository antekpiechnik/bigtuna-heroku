class Project < ActiveRecord::Base
  STATUS_NOT_BUILT = "status_not_built"
  attr_accessor :hook_update

  has_many :builds, :dependent => :destroy
  before_destroy :remove_build_folder
  before_update :rename_build_folder
  before_create :set_default_build_counts
  after_save :update_hooks

  validates :hook_name, :uniqueness => {:allow_blank => true}
  validates :name, :presence => true, :uniqueness => true
  validates :vcs_type, :inclusion => BigTuna::VCS_BACKENDS.map { |e| e::VALUE }
  validates :vcs_source, :presence => true
  validates :vcs_branch, :presence => true

  acts_as_list

  def recent_build
    builds.order("created_at DESC").first
  end

  def build!
    new_total_builds = self.total_builds + 1
    build = nil
    ActiveRecord::Base.transaction do
      build = self.builds.create!({:scheduled_at => Time.now, :build_no => new_total_builds})
      self.update_attributes!(:total_builds => new_total_builds)
    end
    Delayed::Job.enqueue(build)
  end

  def hooks
    hook_hash = {}
    BigTuna::HOOKS.each do |hook|
      hook_hash[hook::NAME] = hook
    end
    Hook.where(:project_id => self.id)
  end

  def build_dir
    build_dir_from_name(name)
  end

  def truncate_builds!
    builds.order("created_at DESC").offset(self.max_builds).each do |build|
      build.destroy
    end
  end

  def max_builds
    super || 10
  end

  def status
    build = recent_build
    build.nil? ? STATUS_NOT_BUILT : build.status
  end

  def vcs
    return @vcs if @vcs
    klass = BigTuna::VCS_BACKENDS.find { |e| e::VALUE == vcs_type }
    raise ArgumentError.new("VCS not supported: %p" % [vcs_type]) if klass.nil?
    @vcs = klass.new(self.vcs_source, self.vcs_branch)
  end

  def to_param
    [self.id, self.name.to_url].join("-")
  end

  def stability
    last_builds = builds.order("created_at DESC").
      where(:status => [Build::STATUS_OK, Build::STATUS_FAILED, Build::STATUS_BUILDER_ERROR]).
      limit(5)
    statuses = last_builds.map { |e| e.status }
    return -1 if statuses.size < 5
    statuses.count { |e| e == Build::STATUS_OK }
  end

  def hooks=(hooks)
    @_hooks = hooks
  end

  private
  def build_dir_from_name(name)
    File.join(Rails.root, "tmp", name.downcase.gsub(/[^A-Za-z0-9]/, "_"))
  end

  def remove_build_folder
    if File.directory?(self.build_dir)
      FileUtils.rm_rf(self.build_dir)
    else
      Rails.logger.debug("[BigTuna] Couldn't find build dir: %p" % [self.build_dir])
    end
  end

  def rename_build_folder
    if self.name_changed?
      old_dir = build_dir_from_name(self.name_was)
      new_dir = build_dir_from_name(self.name)
      FileUtils.mv(old_dir, new_dir)
    end
  end

  def set_default_build_counts
    self.total_builds = 0
    self.failed_builds = 0
  end

  def update_hooks
    return unless self.hook_update
    new_hooks = (@_hooks || {}).keys
    current_hooks = self.hooks.map { |e| e.hook_name }
    to_remove = current_hooks - new_hooks
    to_add = new_hooks - current_hooks
    Hook.where(:project_id => self.id, :hook_name => to_remove).delete_all
    to_add.each do |name|
      Hook.create!(:project => self, :hook_name => name)
    end
  end
end
